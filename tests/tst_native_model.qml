import QtQuick
import QtTest
import "../WindowModel.js" as WindowModel

TestCase {
    id: testCase
    name: "NativeWindowModel"

    Component {
        id: toplevelComponent

        QtObject {
            property string address: "abc123"
            property string title: "Window title"
            property var lastIpcObject: ({
                mapped: true,
                class: "native.class",
                initialClass: "native.initial",
                size: [1600, 1000],
                pinned: false
            })
            property var workspace: ({id: 2, name: "2"})
            property var monitor: ({id: 0, name: "DP-1"})
            property var wayland: ({appId: "wayland.app"})
        }
    }

    function createToplevel(properties) {
        var toplevel = toplevelComponent.createObject(testCase, properties || {});
        verify(toplevel !== null);
        return toplevel;
    }

    function test_usesStableNativeAddress() {
        var toplevel = createToplevel();
        compare(WindowModel.addressFor(toplevel), "0xabc123");
        toplevel.address = "not-an-address";
        compare(WindowModel.addressFor(toplevel), "");
        toplevel.destroy();
    }

    function test_prefersWaylandAppIdWithNativeFallback() {
        var toplevel = createToplevel();
        compare(WindowModel.appIdFor(toplevel), "wayland.app");
        toplevel.wayland.appId = "";
        compare(WindowModel.appIdFor(toplevel), "native.class");
        toplevel.lastIpcObject = ({initialClass: "native.initial"});
        compare(WindowModel.appIdFor(toplevel), "native.initial");
        toplevel.destroy();
    }

    function test_excludesUnmappedOrUncapturableWindows() {
        var toplevel = createToplevel();
        verify(WindowModel.isEligible(toplevel));
        toplevel.lastIpcObject = ({mapped: false});
        verify(!WindowModel.isEligible(toplevel));
        toplevel.lastIpcObject = ({mapped: true});
        toplevel.wayland = null;
        verify(!WindowModel.isEligible(toplevel));
        toplevel.destroy();
    }

    function test_matchesWorkspaceIdentityAndPinnedWindows() {
        var toplevel = createToplevel();
        verify(WindowModel.isOnWorkspace(toplevel, {id: 2, name: "2"}));
        verify(!WindowModel.isOnWorkspace(toplevel, {id: 3, name: "3"}));
        toplevel.lastIpcObject = ({pinned: true});
        verify(WindowModel.isOnWorkspace(toplevel, {id: 3, name: "3"}));
        toplevel.destroy();
    }

    function test_matchesScreenOnlyInPerMonitorMode() {
        var toplevel = createToplevel();
        verify(WindowModel.isOnScreen(toplevel, "DP-1", true));
        verify(!WindowModel.isOnScreen(toplevel, "HDMI-A-1", true));
        verify(WindowModel.isOnScreen(toplevel, "HDMI-A-1", false));
        toplevel.monitor = null;
        verify(!WindowModel.isOnScreen(toplevel, "DP-1", true));
        verify(WindowModel.isOnScreen(toplevel, "DP-1", false));
        toplevel.destroy();
    }

    function test_readsAndClampsNativeAspectRatio() {
        var toplevel = createToplevel();
        compare(WindowModel.aspectRatioFor(toplevel), 1.6);
        toplevel.lastIpcObject = ({size: [10000, 100]});
        compare(WindowModel.aspectRatioFor(toplevel), 4);
        toplevel.lastIpcObject = ({size: [100, 10000]});
        compare(WindowModel.aspectRatioFor(toplevel), 0.45);
        toplevel.lastIpcObject = ({size: [0, 0]});
        compare(WindowModel.aspectRatioFor(toplevel), 1.6);
        toplevel.lastIpcObject = ({size: [NaN, 100]});
        compare(WindowModel.aspectRatioFor(toplevel), 1.6);
        toplevel.lastIpcObject = ({size: [100, Infinity]});
        compare(WindowModel.aspectRatioFor(toplevel), 1.6);
        toplevel.destroy();
    }

    function test_searchesAllNativeIdentityFields() {
        var toplevel = createToplevel();
        verify(WindowModel.searchTextFor(toplevel).includes("wayland.app"));
        verify(WindowModel.searchTextFor(toplevel).includes("native.class"));
        verify(WindowModel.searchTextFor(toplevel).includes("native.initial"));
        verify(WindowModel.searchTextFor(toplevel).includes("window title"));
        toplevel.destroy();
    }

    function test_promotesRecentAddressToFront() {
        compare(WindowModel.promoteRecent([], "0xa", 3), ["0xa"]);
        compare(WindowModel.promoteRecent(["0xa", "0xb", "0xc"], "0xc", 3), ["0xc", "0xa", "0xb"]);
        compare(WindowModel.promoteRecent(["0xa", "0xb", "0xc"], "0xd", 3), ["0xd", "0xa", "0xb"]);
    }

    function test_sortsByRecentThenFocusHistory() {
        var first = createToplevel({address: "a1", lastIpcObject: ({focusHistoryID: 3})});
        var second = createToplevel({address: "b2", lastIpcObject: ({focusHistoryID: 1})});
        var third = createToplevel({address: "c3", lastIpcObject: ({})});
        var fourth = createToplevel({address: "d4", lastIpcObject: ({focusHistoryID: 0})});
        var windows = [first, second, third, fourth];

        compare(WindowModel.sortByRecent(windows, []), [fourth, second, first, third]);
        compare(WindowModel.sortByRecent(windows, ["0xa1", "0xc3"]), [first, third, fourth, second]);
        compare(WindowModel.sortByRecent([], ["0xa1"]), []);
        for (var index = 0; index < windows.length; index++)
            windows[index].destroy();
    }

    function test_partitionsRowsInOrder() {
        compare(WindowModel.partitionInOrder([1, 1, 1, 1], 2), [[0, 1], [2, 3]]);
        compare(WindowModel.partitionInOrder([3, 1, 1, 1], 2), [[0], [1, 2, 3]]);
        compare(WindowModel.partitionInOrder([1, 2, 3], 1), [[0, 1, 2]]);
        compare(WindowModel.partitionInOrder([1, 2], 5), [[0], [1]]);
        var rows = WindowModel.partitionInOrder([1.2, 0.8, 1.6, 1, 1, 0.5, 1.3], 3);
        var flat = [];
        for (var row = 0; row < rows.length; row++) {
            verify(rows[row].length > 0);
            flat = flat.concat(rows[row]);
        }
        compare(flat, [0, 1, 2, 3, 4, 5, 6]);
    }

    function test_seedsRecentFromFocusHistory() {
        var clients = [
            {address: "0xc", focusHistoryID: 2},
            {address: "0xa", focusHistoryID: 0},
            {address: "bad", focusHistoryID: 1},
            {address: "0xb", focusHistoryID: 1},
            {address: "0xd"}
        ];
        compare(WindowModel.seedRecent([], clients), ["0xa", "0xb", "0xc"]);
        compare(WindowModel.seedRecent(["0xc"], clients), ["0xc", "0xa", "0xb"]);
        compare(WindowModel.seedRecent(["0xa"], null), ["0xa"]);
    }
}
