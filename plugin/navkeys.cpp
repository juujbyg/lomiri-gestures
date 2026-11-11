// LomiriNav: lets the Lomiri shell press navigation keys in the focused app,
// and keeps the navigation button's settings.
//
// The shell runs as the seat user, who may use /dev/uinput (udev "uaccess");
// confined apps may not. The virtual device only has the few keys it needs,
// so udev doesn't tag it ID_INPUT_KEYBOARD and Lomiri doesn't count it as a
// hardware keyboard (which would hide the on-screen keyboard).
//
// QML (with QML2_IMPORT_PATH set to the folder holding LomiriNav/):  import LomiriNav 1.0
//       NavKeys.back()     Alt+Left, the Back shortcut (StandardKey.Back)
//       NavKeys.apps()     Super+W, Lomiri's app spread
//       NavKeys.mode       "off", "button" (floating back button) or "bar" (Back, Home, Apps)
//       NavKeys.side       "left", "center" or "right"; NavKeys.position 0 (bottom) to 1 (top)

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

class NavKeys : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY settingsChanged)
    Q_PROPERTY(QString side READ side WRITE setSide NOTIFY settingsChanged)
    Q_PROPERTY(qreal position READ position WRITE setPosition NOTIFY settingsChanged)

public:
    explicit NavKeys(QObject *parent = nullptr) : QObject(parent)
    {
        m_dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/lomiri-nav";
        QDir().mkpath(m_dir);
        m_path = m_dir + "/settings.conf";
        load();
        // QSettings replaces the file when it saves, so watch the folder too.
        m_watcher.addPath(m_dir);
        if (QFile::exists(m_path)) m_watcher.addPath(m_path);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &NavKeys::reload);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &NavKeys::reload);
        openDevice();
    }

    ~NavKeys() override
    {
        if (m_fd >= 0) {
            ioctl(m_fd, UI_DEV_DESTROY);
            close(m_fd);
        }
    }

    bool ready() const { return m_ready; }
    QString mode() const { return m_mode; }
    QString side() const { return m_side; }
    qreal position() const { return m_position; }

    void setMode(const QString &v)
    {
        QString m = cleanMode(v);
        if (m != m_mode) { m_mode = m; save(); }
    }
    void setSide(const QString &v)
    {
        QString s = cleanSide(v);
        if (s != m_side) { m_side = s; save(); }
    }
    void setPosition(qreal v)
    {
        v = qBound<qreal>(0.0, v, 1.0);
        if (!qFuzzyCompare(v + 1, m_position + 1)) { m_position = v; save(); }
    }

    Q_INVOKABLE bool back() { return combo({KEY_LEFTALT, KEY_LEFT}); }
    Q_INVOKABLE bool apps() { return combo({KEY_LEFTMETA, KEY_W}); }
    Q_INVOKABLE bool escape() { return combo({KEY_ESC}); }

Q_SIGNALS:
    void readyChanged();
    void settingsChanged();

private:
    void openDevice()
    {
        m_fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK | O_CLOEXEC);
        if (m_fd < 0) {
            qWarning("LomiriNav: cannot open /dev/uinput: %s", strerror(errno));
            return;
        }
        struct uinput_setup setup;
        memset(&setup, 0, sizeof setup);
        setup.id.bustype = BUS_VIRTUAL;
        setup.id.vendor = 0x1;
        setup.id.product = 0x4e56;  // "NV"
        setup.id.version = 1;
        strncpy(setup.name, "lomiri-nav-keys", UINPUT_MAX_NAME_SIZE - 1);
        bool ok = ioctl(m_fd, UI_SET_EVBIT, EV_KEY) == 0;
        for (int k : KEYS) ok = ok && ioctl(m_fd, UI_SET_KEYBIT, k) == 0;
        ok = ok && ioctl(m_fd, UI_DEV_SETUP, &setup) == 0 && ioctl(m_fd, UI_DEV_CREATE) == 0;
        if (!ok) {
            qWarning("LomiriNav: cannot create the virtual key device: %s", strerror(errno));
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
        if (!ok) qWarning("LomiriNav: writing a key failed: %s", strerror(errno));
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

    void load()
    {
        QSettings s(m_path, QSettings::IniFormat);
        // Before modes there was only "enabled" for the back button.
        QString fallback = s.value("enabled", true).toBool() ? "button" : "off";
        m_mode = cleanMode(s.value("mode", fallback).toString());
        m_side = cleanSide(s.value("side", "right").toString());
        m_position = qBound<qreal>(0.0, s.value("position", 0.0).toReal(), 1.0);
    }

    void save()
    {
        {
            QSettings s(m_path, QSettings::IniFormat);
            s.remove("enabled");
            s.setValue("mode", m_mode);
            s.setValue("side", m_side);
            s.setValue("position", m_position);
        }
        Q_EMIT settingsChanged();
    }

    void reload()
    {
        if (QFile::exists(m_path) && !m_watcher.files().contains(m_path)) m_watcher.addPath(m_path);
        QString m = m_mode, s = m_side; qreal p = m_position;
        load();
        if (m != m_mode || s != m_side || !qFuzzyCompare(p + 1, m_position + 1)) Q_EMIT settingsChanged();
    }

    int m_fd = -1;
    bool m_ready = false;
    bool m_busy = false;
    QString m_mode = "button";
    QString m_side = "right";
    qreal m_position = 0.0;
    QString m_dir, m_path;
    QFileSystemWatcher m_watcher;
};

class LomiriNavPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface/1.0")

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterSingletonType<NavKeys>(uri, 1, 0, "NavKeys",
            [](QQmlEngine *, QJSEngine *) -> QObject * { return new NavKeys; });
    }
};

#include "navkeys.moc"
