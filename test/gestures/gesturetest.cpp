// Drives MultiFingerGestures.qml with real Qt touch events and checks what it
// reports. Run on the phone (see run-tests.sh); prints PASS/FAIL per case.
#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QSignalSpy>
#include <QTest>
#include <QTouchDevice>
#include <QtMath>
#include <functional>

struct Pt { qreal x, y; };
using Path = std::function<Pt(Pt, qreal)>;

static QQuickView *view;
static QQuickItem *gestures;
static QTouchDevice *device;
static int failures = 0;

static QPoint q(Pt p) { return QPoint(qRound(p.x), qRound(p.y)); }

static QVector<Pt> fingersAt(int n, qreal gap)
{
    QVector<Pt> pts;
    const qreal cx = view->width() / 2.0, cy = view->height() / 2.0;
    for (int i = 0; i < n; i++) {
        qreal a = 2 * M_PI * i / n;
        pts.append({cx + gap * qCos(a), cy + gap * qSin(a)});
    }
    return pts;
}

static Path translate(qreal dx, qreal dy)
{
    return [=](Pt p, qreal t) { return Pt{p.x + dx * t, p.y + dy * t}; };
}

static Path scale(qreal k)
{
    return [=](Pt p, qreal t) {
        const qreal cx = view->width() / 2.0, cy = view->height() / 2.0;
        qreal f = 1 + (k - 1) * t;
        return Pt{cx + (p.x - cx) * f, cy + (p.y - cy) * f};
    };
}

// Pinch about a point off the fingers' centre, as a hand does: the centre drifts.
static Path scaleAbout(qreal ox, qreal oy, qreal k)
{
    return [=](Pt p, qreal t) {
        const qreal cx = view->width() / 2.0 + ox, cy = view->height() / 2.0 + oy;
        qreal f = 1 + (k - 1) * t;
        return Pt{cx + (p.x - cx) * f, cy + (p.y - cy) * f};
    };
}

// Fingers down, `steps` moves along path, then release (all at once, or one
// finger every releaseGapMs). Returns the last positions.
static QVector<Pt> gesture(const QVector<Pt> &pts, Path path, int steps, int releaseGapMs = 0,
                           bool release = true)
{
    auto seq = QTest::touchEvent(view, device);
    for (int i = 0; i < pts.size(); i++) seq.press(i, q(pts[i]), view);
    seq.commit();
    QTest::qWait(20);
    QVector<Pt> last = pts;
    for (int s = 1; s <= steps; s++) {
        auto mv = QTest::touchEvent(view, device);
        for (int j = 0; j < pts.size(); j++) {
            last[j] = path(pts[j], qreal(s) / steps);
            mv.move(j, q(last[j]), view);
        }
        mv.commit();
        QTest::qWait(16);
    }
    if (!release) return last;
    if (releaseGapMs) {
        QVector<bool> down(pts.size(), true);
        for (int k = 0; k < last.size(); k++) {
            auto rl = QTest::touchEvent(view, device);
            for (int j = 0; j < last.size(); j++) {
                if (j == k) rl.release(j, q(last[j]), view);
                else if (down[j]) rl.stationary(j);
            }
            down[k] = false;
            rl.commit();
            QTest::qWait(releaseGapMs);
        }
    } else {
        auto rl = QTest::touchEvent(view, device);
        for (int r = 0; r < last.size(); r++) rl.release(r, q(last[r]), view);
        rl.commit();
    }
    QTest::qWait(60);
    return last;
}

static void check(const char *name, bool ok, const QString &detail = QString())
{
    printf("%s %s %s\n", ok ? "PASS" : "FAIL", name, qPrintable(detail));
    fflush(stdout);
    if (!ok) failures++;
}

static void expect(const char *name, QSignalSpy &spy, const QString &gesture, int fingers)
{
    QString got;
    for (const auto &args : spy) got += args.at(0).toString() + "/" + args.at(1).toString() + " ";
    bool ok = spy.count() == 1 && spy.at(0).at(0).toString() == gesture &&
              spy.at(0).at(1).toInt() == fingers;
    check(name, ok, "want " + gesture + "/" + QString::number(fingers) + ", got [" + got.trimmed() + "]");
}

static void expectNone(const char *name, QSignalSpy &spy)
{
    QString got;
    for (const auto &args : spy) got += args.at(0).toString() + "/" + args.at(1).toString() + " ";
    check(name, spy.count() == 0, "want nothing, got [" + got.trimmed() + "]");
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    device = QTest::createTouchDevice();

    view = new QQuickView;
    view->setResizeMode(QQuickView::SizeRootObjectToView);
    view->resize(540, 1080);
    view->setSource(QUrl::fromLocalFile(argc > 1 ? argv[1] : "harness.qml"));
    if (view->status() != QQuickView::Ready) {
        for (const auto &e : view->errors()) printf("QML error: %s\n", qPrintable(e.toString()));
        return 2;
    }
    view->show();
    QTest::qWaitForWindowExposed(view);
    gestures = view->rootObject()->findChild<QQuickItem *>("gestures");
    if (!gestures) { printf("no gestures item\n"); return 2; }

    QSignalSpy spy(gestures, SIGNAL(triggered(QString, int)));
    auto run = [&](std::function<void()> f) {
        spy.clear();
        for (int i = 0; i < 100 && gestures->property("status").toInt() != 0; i++) QTest::qWait(20);
        f();
    };

    struct Swipe { const char *name; int n; qreal dx, dy; const char *want; };
    for (const Swipe &s : {Swipe{"3 fingers left", 3, -200, 0, "swipeLeft"},
                           Swipe{"3 fingers right", 3, 200, 0, "swipeRight"},
                           Swipe{"3 fingers up", 3, 0, -250, "swipeUp"},
                           Swipe{"3 fingers down", 3, 0, 250, "swipeDown"},
                           Swipe{"4 fingers left", 4, -200, 30, "swipeLeft"},
                           Swipe{"4 fingers up", 4, 20, -250, "swipeUp"}}) {
        run([&] { gesture(fingersAt(s.n, 60), translate(s.dx, s.dy), 12); expect(s.name, spy, s.want, s.n); });
    }

    struct Pinch { const char *name; int n; qreal k; const char *want; };
    for (const Pinch &p : {Pinch{"4 fingers pinch in", 4, 0.4, "pinchIn"},
                           Pinch{"4 fingers spread out", 4, 2.2, "pinchOut"},
                           Pinch{"3 fingers pinch in", 3, 0.4, "pinchIn"}}) {
        run([&] { gesture(fingersAt(p.n, 120), scale(p.k), 12); expect(p.name, spy, p.want, p.n); });
    }

    run([&] { gesture(fingersAt(3, 100), scaleAbout(90, 0, 0.45), 12); expect("3 fingers pinch in, hand drift", spy, "pinchIn", 3); });
    run([&] { gesture(fingersAt(3, 100), scaleAbout(0, -90, 0.45), 12); expect("3 fingers pinch in, drift up", spy, "pinchIn", 3); });
    run([&] { gesture(fingersAt(4, 60), translate(0, 0), 1); expect("4 finger tap", spy, "tap", 4); });
    QObject *appArea = view->rootObject()->findChild<QObject *>("app");
    run([&] {
        appArea->setProperty("maxPressed", 0);
        appArea->setProperty("moved", 0);
        gesture(fingersAt(2, 60), translate(-250, 0), 12);
        expectNone("2 fingers left to apps", spy);
        check("app gets 2-finger drag",
              appArea->property("moved").toReal() > 200,
              "app moved " + appArea->property("moved").toString() + "px");
    });
    run([&] { gesture(fingersAt(5, 80), translate(-250, 0), 12); expectNone("5 fingers ignored", spy); });
    run([&] {
        gesture(fingersAt(3, 60), [](Pt p, qreal t) {
            qreal d = t < 0.5 ? -600 * t : -600 * (1 - t);
            return Pt{p.x + d, p.y};
        }, 20);
        expectNone("moving back cancels", spy);
    });
    run([&] { gesture(fingersAt(3, 60), translate(-30, 10), 6); expectNone("small wobble ignored", spy); });
    run([&] { gesture(fingersAt(3, 60), translate(-200, 0), 12, 80); expect("staggered lift still counts", spy, "swipeLeft", 3); });

    run([&] {
        auto pts = fingersAt(3, 60);
        auto last = gesture(pts, translate(0, -250), 10, 0, false);
        QQuickItem *hint = gestures->findChild<QQuickItem *>("multiFingerGestureHint");
        check("hint while fingers down",
              gestures->property("pendingGesture").toString() == "swipeUp" && hint &&
              hint->property("text").toString() == "swipeUp/3",
              "pending=" + gestures->property("pendingGesture").toString() +
              " hint=" + (hint ? hint->property("text").toString() : "none"));
        auto rl = QTest::touchEvent(view, device);
        for (int r = 0; r < 3; r++) rl.release(r, q(last[r]), view);
        rl.commit();
        QTest::qWait(60);
        expect("hint gesture fires on release", spy, "swipeUp", 3);
        check("hint cleared after release", gestures->property("pendingGesture").toString().isEmpty());
    });

    printf("%s: %d failure(s)\n", failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
