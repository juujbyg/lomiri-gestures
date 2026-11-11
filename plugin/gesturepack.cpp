// GesturePack: lets the Lomiri shell press navigation keys in the focused app,
// and keeps the Gesture Pack's settings, reloading them when the file changes.
//
// The shell runs as the seat user, who may use /dev/uinput (udev "uaccess");
// confined apps may not. The virtual device only has the few keys it needs,
// so udev doesn't tag it ID_INPUT_KEYBOARD and Lomiri doesn't count it as a
// hardware keyboard (which would hide the on-screen keyboard).
//
// QML (with QML2_IMPORT_PATH set to the folder holding GesturePack/):
//   import GesturePack 1.0
//   GesturePack.back()            Alt+Left, the Back shortcut (StandardKey.Back)
//   GesturePack.apps()            Super+W, Lomiri's app spread
//   GesturePack.mode              "off", "button" (floating back button) or "bar" (Back, Home, Apps)
//   GesturePack.side              "left", "center" or "right"; position 0 (bottom) to 1 (top)
//   GesturePack.barScreenshot     the bar has a Screenshot button
//   GesturePack.gestures          three-finger gestures
//   GesturePack.swipeScreenshot   three fingers down takes a screenshot
//   GesturePack.lockButtons       camera and flashlight on the lock screen
//
// Settings live in ~/.config/lomiri-gesture-pack/settings.conf ([General]).

#include <QDir>
#include <QFileSystemWatcher>
#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QtQml>

#include <fcntl.h>
#include <linux/uinput.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static const int KEYS[] = {KEY_LEFTALT, KEY_LEFT, KEY_LEFTMETA, KEY_W, KEY_ESC};
static const int SETTLE_MS = 1000;  // the compositor needs a moment to pick up a new device
static const int HOLD_MS = 30;      // time between pressing and releasing

class GesturePack : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY settingsChanged)
    Q_PROPERTY(QString side READ side WRITE setSide NOTIFY settingsChanged)
    Q_PROPERTY(qreal position READ position WRITE setPosition NOTIFY settingsChanged)
    Q_PROPERTY(bool barScreenshot READ barScreenshot WRITE setBarScreenshot NOTIFY settingsChanged)
    Q_PROPERTY(bool gestures READ gestures WRITE setGestures NOTIFY settingsChanged)
    Q_PROPERTY(bool swipeScreenshot READ swipeScreenshot WRITE setSwipeScreenshot NOTIFY settingsChanged)
    Q_PROPERTY(bool lockButtons READ lockButtons WRITE setLockButtons NOTIFY settingsChanged)

public:
    explicit GesturePack(QObject *parent = nullptr) : QObject(parent)
    {
        m_dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/lomiri-gesture-pack";
        QDir().mkpath(m_dir);
        m_path = m_dir + "/settings.conf";
        load();
        // QSettings replaces the file when it saves, so watch the folder too.
        m_watcher.addPath(m_dir);
        if (QFile::exists(m_path)) m_watcher.addPath(m_path);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &GesturePack::reload);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &GesturePack::reload);
        openDevice();
    }

    ~GesturePack() override
    {
        if (m_fd >= 0) {
            ioctl(m_fd, UI_DEV_DESTROY);
            close(m_fd);
        }
    }

    bool ready() const { return m_ready; }
    QString mode() const { return m_s.mode; }
    QString side() const { return m_s.side; }
    qreal position() const { return m_s.position; }
    bool barScreenshot() const { return m_s.barScreenshot; }
    bool gestures() const { return m_s.gestures; }
    bool swipeScreenshot() const { return m_s.swipeScreenshot; }
    bool lockButtons() const { return m_s.lockButtons; }

    void setMode(const QString &v) { Settings s = m_s; s.mode = cleanMode(v); apply(s); }
    void setSide(const QString &v) { Settings s = m_s; s.side = cleanSide(v); apply(s); }
    void setPosition(qreal v) { Settings s = m_s; s.position = qBound<qreal>(0.0, v, 1.0); apply(s); }
    void setBarScreenshot(bool v) { Settings s = m_s; s.barScreenshot = v; apply(s); }
    void setGestures(bool v) { Settings s = m_s; s.gestures = v; apply(s); }
    void setSwipeScreenshot(bool v) { Settings s = m_s; s.swipeScreenshot = v; apply(s); }
    void setLockButtons(bool v) { Settings s = m_s; s.lockButtons = v; apply(s); }

    Q_INVOKABLE bool back() { return combo({KEY_LEFTALT, KEY_LEFT}); }
    Q_INVOKABLE bool apps() { return combo({KEY_LEFTMETA, KEY_W}); }
    Q_INVOKABLE bool escape() { return combo({KEY_ESC}); }

Q_SIGNALS:
    void readyChanged();
    void settingsChanged();

private:
    struct Settings {
        QString mode = "button";
        QString side = "right";
        qreal position = 0.0;
        bool barScreenshot = true;
        bool gestures = true;
        bool swipeScreenshot = true;
        bool lockButtons = true;
        bool operator==(const Settings &o) const
        {
            return mode == o.mode && side == o.side && qFuzzyCompare(position + 1, o.position + 1)
                && barScreenshot == o.barScreenshot && gestures == o.gestures
                && swipeScreenshot == o.swipeScreenshot && lockButtons == o.lockButtons;
        }
    };

    void openDevice()
    {
        m_fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK | O_CLOEXEC);
        if (m_fd < 0) {
            qWarning("GesturePack: cannot open /dev/uinput: %s", strerror(errno));
            return;
        }
        struct uinput_setup setup;
        memset(&setup, 0, sizeof setup);
        setup.id.bustype = BUS_VIRTUAL;
        setup.id.vendor = 0x1;
        setup.id.product = 0x4750;  // "GP"
        setup.id.version = 1;
        strncpy(setup.name, "gesture-pack-keys", UINPUT_MAX_NAME_SIZE - 1);
        bool ok = ioctl(m_fd, UI_SET_EVBIT, EV_KEY) == 0;
        for (int k : KEYS) ok = ok && ioctl(m_fd, UI_SET_KEYBIT, k) == 0;
        ok = ok && ioctl(m_fd, UI_DEV_SETUP, &setup) == 0 && ioctl(m_fd, UI_DEV_CREATE) == 0;
        if (!ok) {
            qWarning("GesturePack: cannot create the virtual key device: %s", strerror(errno));
            close(m_fd);
            m_fd = -1;
            return;
        }
        QTimer::singleShot(SETTLE_MS, this, [this]() { m_ready = true; Q_EMIT readyChanged(); });
    }

    bool emitKey(int code, int value)
    {
        struct input_event ev[2];
        memset(ev, 0, sizeof ev);
        ev[0].type = EV_KEY; ev[0].code = code; ev[0].value = value;
        ev[1].type = EV_SYN; ev[1].code = SYN_REPORT; ev[1].value = 0;
        return write(m_fd, ev, sizeof ev) == (ssize_t)sizeof ev;
    }

    bool combo(const QList<int> &keys)
    {
        if (!m_ready || m_busy) return false;
        bool ok = true;
        for (int k : keys) ok = emitKey(k, 1) && ok;
        m_busy = true;
        QTimer::singleShot(HOLD_MS, this, [this, keys]() {
            for (int i = keys.size() - 1; i >= 0; --i) emitKey(keys[i], 0);
            m_busy = false;
        });
        if (!ok) qWarning("GesturePack: writing a key failed: %s", strerror(errno));
        return ok;
    }

    static QString cleanMode(const QString &v)
    {
        return (v == "off" || v == "bar") ? v : QStringLiteral("button");
    }
    static QString cleanSide(const QString &v)
    {
        return (v == "left" || v == "center") ? v : QStringLiteral("right");
    }
    // Qt.labs.settings writes booleans as "true"/"false".
    static bool toBool(const QVariant &v, bool fallback)
    {
        if (!v.isValid()) return fallback;
        QString s = v.toString().trimmed().toLower();
        if (s == "true" || s == "1") return true;
        if (s == "false" || s == "0") return false;
        return fallback;
    }

    Settings read() const
    {
        QSettings q(m_path, QSettings::IniFormat);
        Settings s;
        s.mode = cleanMode(q.value("mode", s.mode).toString());
        s.side = cleanSide(q.value("side", s.side).toString());
        s.position = qBound<qreal>(0.0, q.value("position", 0.0).toReal(), 1.0);
        s.barScreenshot = toBool(q.value("barScreenshot"), s.barScreenshot);
        s.gestures = toBool(q.value("gestures"), s.gestures);
        s.swipeScreenshot = toBool(q.value("swipeScreenshot"), s.swipeScreenshot);
        s.lockButtons = toBool(q.value("lockButtons"), s.lockButtons);
        return s;
    }

    void load() { m_s = read(); }

    // Only the keys the shell itself changes (dragging, the hold menu) are written.
    void apply(const Settings &s)
    {
        if (s == m_s) return;
        {
            QSettings q(m_path, QSettings::IniFormat);
            if (s.mode != m_s.mode) q.setValue("mode", s.mode);
            if (s.side != m_s.side) q.setValue("side", s.side);
            if (!qFuzzyCompare(s.position + 1, m_s.position + 1)) q.setValue("position", s.position);
            if (s.barScreenshot != m_s.barScreenshot) q.setValue("barScreenshot", s.barScreenshot);
            if (s.gestures != m_s.gestures) q.setValue("gestures", s.gestures);
            if (s.swipeScreenshot != m_s.swipeScreenshot) q.setValue("swipeScreenshot", s.swipeScreenshot);
            if (s.lockButtons != m_s.lockButtons) q.setValue("lockButtons", s.lockButtons);
        }
        m_s = s;
        Q_EMIT settingsChanged();
    }

    void reload()
    {
        if (QFile::exists(m_path) && !m_watcher.files().contains(m_path)) m_watcher.addPath(m_path);
        Settings s = read();
        if (!(s == m_s)) { m_s = s; Q_EMIT settingsChanged(); }
    }

    int m_fd = -1;
    bool m_ready = false;
    bool m_busy = false;
    Settings m_s;
    QString m_dir, m_path;
    QFileSystemWatcher m_watcher;
};

class GesturePackPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface/1.0")

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterSingletonType<GesturePack>(uri, 1, 0, "GesturePack",
            [](QQmlEngine *, QJSEngine *) -> QObject * { return new GesturePack; });
    }
};

#include "gesturepack.moc"
