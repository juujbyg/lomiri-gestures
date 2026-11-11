// A UI toolkit app with the two kinds of back an app can have:
// page 2 has the toolkit's own back (PageStack), page 3 an app-made back arrow,
// and page 4 a menu icon that Back must NOT trigger. Each Back press is logged.
import QtQuick 2.12
import Lomiri.Components 1.3

MainView {
    width: units.gu(40); height: units.gu(70)
    PageStack {
        id: stack
        Component.onCompleted: { push(page1); push(page2); push(page3); push(page4) }
    }
    Page { id: page1; visible: false; header: PageHeader { title: "1" } }
    Page { id: page2; visible: false; header: PageHeader { title: "2 (toolkit back)" } }
    Page {
        id: page3; visible: false
        header: PageHeader {
            title: "3 (app-made back)"
            leadingActionBar.actions: Action { iconName: "back"; onTriggered: { console.log("HB custom back on page 3"); stack.pop() } }
        }
    }
    Page {
        id: page4; visible: false
        header: PageHeader {
            title: "4 (menu)"
            leadingActionBar.actions: Action { iconName: "navigation-menu"; onTriggered: console.log("HB WRONG: menu opened by Back") }
        }
    }
    Timer {
        interval: 500; running: true; repeat: true
        property string last: ""
        onTriggered: {
            var t = stack.currentPage ? stack.currentPage.header.title : "none"
            var acts = stack.currentPage ? stack.currentPage.header.leadingActionBar.actions : []
            var a = acts.length ? acts[0] : null
            var d = a ? (a.iconName + " visible=" + a.visible + " enabled=" + a.enabled + " barVisible=" + stack.currentPage.header.leadingActionBar.visible + " headerVisible=" + stack.currentPage.header.visible) : "no action"
            if (t + d !== last) { console.log("HB top page: " + t + " (depth " + stack.depth + ") leading: " + d); last = t + d }
        }
    }
    // Back on page 4 must do nothing; after the first press the test removes page 4 itself.
    Timer { interval: 7700; running: true; onTriggered: { console.log("HB test pops page 4 by hand"); stack.pop() } }
    Timer { interval: 26000; running: true; onTriggered: Qt.quit() }
}
