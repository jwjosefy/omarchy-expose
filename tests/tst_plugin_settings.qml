import QtQuick
import QtTest
import ".."

TestCase {
    id: testCase
    name: "PluginSettings"

    property var store: null
    property var hostEntry: null
    property var writes: []
    property bool rejectWrites: false

    Component {
        id: settingsComponent
        PluginSettings {
            pluginId: "expose.switch"
            shell: QtObject {
                // Like PluginShellApi, this deliberately has no shellConfig.
                function updateEntryInline(id, settings) {
                    if (testCase.rejectWrites)
                        return false;
                    var next = Object.assign({id: id}, settings);
                    if (JSON.stringify(next) === JSON.stringify(testCase.hostEntry))
                        return false;
                    testCase.hostEntry = next;
                    testCase.writes = testCase.writes.concat([next]);
                    return true;
                }
            }
        }
    }

    function config(entry) {
        return JSON.stringify({version: 1, plugins: [
            {id: "another.plugin", keep: "unrelated"}, entry
        ]});
    }

    function init() {
        hostEntry = {id: "expose.switch", hotCornerEnabled: false,
            backgroundDim: 50, unknownSetting: {preserve: true}};
        writes = [];
        rejectWrites = false;
        store = createTemporaryObject(settingsComponent, testCase);
        verify(store !== null);
    }

    function test_loadsSavedSettingsAndExternalChanges() {
        verify(!store.ready);
        store.load(config(hostEntry));
        verify(store.ready);
        compare(store.entry.hotCornerEnabled, false);
        compare(store.entry.backgroundDim, 50);
        hostEntry.backgroundDim = 30;
        store.load(config(hostEntry));
        compare(store.entry.backgroundDim, 30);
        compare(writes.length, 0);
    }

    function test_earlyEditsWaitForInitialReadAndPreserveUnknownKeys() {
        verify(store.update("backgroundBlur", 0));
        store.flush();
        compare(writes.length, 0);
        store.load(config(hostEntry));
        tryCompare(testCase, "writes", [Object.assign({}, hostEntry, {backgroundBlur: 0})]);
        compare(hostEntry.hotCornerEnabled, false);
        compare(hostEntry.unknownSetting, {preserve: true});
    }

    function test_rapidEditsSurviveDelayedSnapshots() {
        var original = config(hostEntry);
        store.load(original);
        store.update("backgroundBlur", 0);
        store.flush();
        compare(writes.length, 1);
        var firstWrite = config(hostEntry);

        store.update("backgroundDim", 70);
        store.update("hotCornerEnabled", true);
        store.update("backgroundBlur", 8);
        store.flush();
        compare(writes.length, 1);
        compare(store.entry.backgroundDim, 70);
        compare(store.entry.backgroundBlur, 8);
        compare(store.entry.hotCornerEnabled, true);

        // A read started before the first write must not undo either edit.
        store.load(original);
        store.flush();
        compare(writes.length, 1);
        compare(store.entry.backgroundBlur, 8);

        store.load(firstWrite);
        store.flush();
        compare(writes.length, 2);
        compare(hostEntry.backgroundBlur, 8);
        compare(hostEntry.backgroundDim, 70);
        compare(hostEntry.hotCornerEnabled, true);
        compare(hostEntry.unknownSetting, {preserve: true});
        store.load(config(hostEntry));
        compare(store.inFlight, null);
        compare(store.pending, {});
    }

    function test_nestedAnimationEditsUseLatestLocalValues() {
        store.load(config(hostEntry));
        store.update("animationTimings", {slide: {"in": 200, "out": 300, separate: true}});
        store.flush();
        var firstWrite = config(hostEntry);
        var timings = JSON.parse(JSON.stringify(store.entry.animationTimings));
        timings.slide.out = 600;
        store.update("animationTimings", timings);
        store.update("slideDirection", {"in": "up", "out": "down"});
        store.load(firstWrite);
        store.flush();
        compare(hostEntry.animationTimings.slide, {"in": 200, "out": 600, separate: true});
        compare(hostEntry.slideDirection, {"in": "up", "out": "down"});
    }

    function test_flushDoesNotTemporarilyRestoreOldValue() {
        store.load(config(hostEntry));
        var observed = [];
        store.entryChanged.connect(function() { observed.push(store.entry.backgroundDim); });
        store.update("backgroundDim", 70);
        store.flush();
        verify(observed.length > 0);
        for (var i = 0; i < observed.length; i++)
            compare(observed[i], 70);
    }

    function test_falseForUnchangedHostStateIsConfirmedByDisk() {
        store.load(config(hostEntry));
        hostEntry = Object.assign({}, hostEntry, {backgroundBlur: 0});
        store.update("backgroundBlur", 0);
        store.flush();
        compare(writes.length, 0);
        store.load(config(hostEntry));
        compare(store.inFlight, null);
        compare(store.entry.backgroundBlur, 0);
    }

    function test_rejectedOrUnsavedWriteRestoresDiskState_data() {
        return [{tag: "rejected", reject: true}, {tag: "accepted but not saved", reject: false}];
    }

    function test_rejectedOrUnsavedWriteRestoresDiskState(data) {
        var original = config(hostEntry);
        store.load(original);
        rejectWrites = data.reject;
        store.update("backgroundDim", 70);
        store.flush();
        store.update("hotCornerEnabled", true);
        compare(store.entry.backgroundDim, 70);
        store.reconcile();
        store.load(original);
        compare(store.entry.backgroundDim, 50);
        compare(store.entry.hotCornerEnabled, false);
        compare(store.inFlight, null);
        compare(store.pending, {});
    }

    function test_invalidOrMissingConfigCannotOverwriteSavedSettings() {
        store.load(config(hostEntry));
        store.load("{broken");
        verify(!store.ready);
        compare(store.entry.backgroundDim, 50);
        store.update("backgroundBlur", 0);
        store.flush();
        compare(writes.length, 0);
        store.loadFailed();
        store.flush();
        compare(writes.length, 0);
        store.load(config(hostEntry));
        store.flush();
        compare(hostEntry.backgroundBlur, 0);
        compare(hostEntry.backgroundDim, 50);
    }

    function test_removedPluginIsNotRecreated() {
        store.load('{"version":1,"plugins":[]}');
        store.update("backgroundBlur", 0);
        store.flush();
        compare(writes.length, 0);
        compare(store.pending, {});
    }
}
