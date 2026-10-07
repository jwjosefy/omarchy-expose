.pragma library

function ipcFor(toplevel) {
    var ipc = toplevel && toplevel.lastIpcObject;
    return ipc && typeof ipc === "object" ? ipc : {};
}

function waylandFor(toplevel) {
    return toplevel && toplevel.wayland ? toplevel.wayland : null;
}

function appIdFor(toplevel) {
    var wayland = waylandFor(toplevel);
    if (wayland && wayland.appId)
        return String(wayland.appId);
    var ipc = ipcFor(toplevel);
    return String(ipc.class || ipc.initialClass || "");
}

function addressFor(toplevel) {
    var address = String((toplevel && toplevel.address) || "");
    return /^[0-9a-fA-F]+$/.test(address) ? "0x" + address : "";
}

function isEligible(toplevel) {
    return Boolean(waylandFor(toplevel)) && ipcFor(toplevel).mapped !== false;
}

function workspaceName(toplevel) {
    var workspace = toplevel && toplevel.workspace ? toplevel.workspace : null;
    return workspace ? String(workspace.name || workspace.id || "—") : "—";
}

function isOnScreen(toplevel, screenName, perMonitor) {
    if (!perMonitor)
        return true;
    var monitor = toplevel && toplevel.monitor ? toplevel.monitor : null;
    return Boolean(monitor) && String(monitor.name || "") === String(screenName || "");
}

function isOnWorkspace(toplevel, workspace) {
    var toplevelWorkspace = toplevel && toplevel.workspace ? toplevel.workspace : null;
    if (!toplevelWorkspace || !workspace)
        return false;
    if (ipcFor(toplevel).pinned === true || toplevelWorkspace === workspace)
        return true;

    var toplevelId = Number(toplevelWorkspace.id);
    var workspaceId = Number(workspace.id);
    if (isFinite(toplevelId) && isFinite(workspaceId) && toplevelId !== 0 && workspaceId !== 0)
        return toplevelId === workspaceId;

    var workspaceName = String(workspace.name || "");
    return Boolean(workspaceName) && String(toplevelWorkspace.name || "") === workspaceName;
}

function aspectRatioFor(toplevel) {
    var size = ipcFor(toplevel).size || [];
    var width = Number(size[0]);
    var height = Number(size[1]);
    if (size.length < 2 || !isFinite(width) || !isFinite(height) || width <= 0 || height <= 0)
        return 1.6;
    return Math.max(0.45, Math.min(4, width / height));
}

function searchTextFor(toplevel) {
    var ipc = ipcFor(toplevel);
    return (appIdFor(toplevel) + " " + String(ipc.class || "") + " "
        + String(ipc.initialClass || "") + " " + String((toplevel && toplevel.title) || "")).toLowerCase();
}

// Hyprland's focus history: 0 is the focused window. Missing means unknown.
function focusHistoryFor(toplevel) {
    var id = Number(ipcFor(toplevel).focusHistoryID);
    return isFinite(id) && id >= 0 ? id : Infinity;
}

// Move address to the front of a most-recently-used list.
function promoteRecent(recentAddresses, address, limit) {
    var next = [address];
    for (var index = 0; index < recentAddresses.length && next.length < limit; index++)
        if (recentAddresses[index] !== address)
            next.push(recentAddresses[index]);
    return next;
}

function compareRanks(a, b) {
    return a === b ? 0 : (a < b ? -1 : 1);
}

// Most recent first. Windows the shell has not seen focused fall back to
// Hyprland's focus history, then keep their original order.
function sortByRecent(toplevels, recentAddresses) {
    var ranked = [];
    for (var index = 0; index < toplevels.length; index++) {
        var address = addressFor(toplevels[index]);
        var recent = address ? recentAddresses.indexOf(address) : -1;
        ranked.push({
            toplevel: toplevels[index],
            recent: recent < 0 ? Infinity : recent,
            history: focusHistoryFor(toplevels[index]),
            index: index
        });
    }
    ranked.sort(function (a, b) {
        return compareRanks(a.recent, b.recent)
            || compareRanks(a.history, b.history)
            || a.index - b.index;
    });
    var result = [];
    for (var sorted = 0; sorted < ranked.length; sorted++)
        result.push(ranked[sorted].toplevel);
    return result;
}

// Split widths into rowCount non-empty rows of consecutive items, keeping
// the widest row as narrow as possible. Returns the item indexes per row.
function partitionInOrder(widths, rowCount) {
    var count = widths.length;
    var rows = Math.max(1, Math.min(rowCount, count));
    var prefix = [0];
    for (var index = 0; index < count; index++)
        prefix.push(prefix[index] + widths[index]);

    // cost[r][i]: widest row when the first i items fill r rows.
    var cost = [];
    var cut = [];
    for (var r = 0; r <= rows; r++) {
        cost.push([]);
        cut.push([]);
        for (var i = 0; i <= count; i++) {
            cost[r].push(Infinity);
            cut[r].push(0);
        }
    }
    cost[0][0] = 0;
    for (var row = 1; row <= rows; row++) {
        for (var end = row; end <= count; end++) {
            for (var start = row - 1; start < end; start++) {
                var widest = Math.max(cost[row - 1][start], prefix[end] - prefix[start]);
                if (widest < cost[row][end]) {
                    cost[row][end] = widest;
                    cut[row][end] = start;
                }
            }
        }
    }

    var result = [];
    var stop = count;
    for (var back = rows; back >= 1; back--) {
        var begin = cut[back][stop];
        var members = [];
        for (var member = begin; member < stop; member++)
            members.push(member);
        result.unshift(members);
        stop = begin;
    }
    return result;
}

// Append windows the shell has not seen focused, in Hyprland's focus history
// order, after the ones it tracked itself.
function seedRecent(recentAddresses, clients) {
    var known = (clients || []).filter(function (client) {
        return client && /^0x[0-9a-fA-F]+$/.test(String(client.address || ""))
            && isFinite(Number(client.focusHistoryID)) && Number(client.focusHistoryID) >= 0;
    });
    known.sort(function (a, b) { return Number(a.focusHistoryID) - Number(b.focusHistoryID); });
    var next = recentAddresses.slice();
    for (var index = 0; index < known.length; index++) {
        var address = String(known[index].address);
        if (next.indexOf(address) === -1)
            next.push(address);
    }
    return next;
}
