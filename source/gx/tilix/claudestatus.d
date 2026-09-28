/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.claudestatus;

enum ClaudeStatus {
    NONE,
    IDLE,
    WORKING,
    WAITING
}

struct ClaudeSummary {
    ClaudeStatus status;
    size_t count;
}

bool parseClaudeStatus(string raw, out ClaudeStatus status) {
    status = ClaudeStatus.NONE;
    switch (raw) {
        case "working": status = ClaudeStatus.WORKING; return true;
        case "waiting": status = ClaudeStatus.WAITING; return true;
        case "idle": status = ClaudeStatus.IDLE; return true;
        case "clear": return true;
        default: return false;
    }
}

ClaudeSummary summarizeClaudeStatus(const(ClaudeStatus)[] states) {
    ClaudeSummary result;
    foreach (status; states) {
        if (status > result.status) {
            result = ClaudeSummary(status, 1);
        } else if (status == result.status && status != ClaudeStatus.NONE) {
            result.count++;
        }
    }
    return result;
}

unittest {
    ClaudeStatus value;
    assert(parseClaudeStatus("working", value) && value == ClaudeStatus.WORKING);
    assert(parseClaudeStatus("clear", value) && value == ClaudeStatus.NONE);
    assert(!parseClaudeStatus("Working", value));
    assert(!parseClaudeStatus("", value));
    assert(summarizeClaudeStatus([ClaudeStatus.IDLE, ClaudeStatus.WAITING,
        ClaudeStatus.WORKING]).status == ClaudeStatus.WAITING);
    assert(summarizeClaudeStatus([ClaudeStatus.WAITING, ClaudeStatus.WAITING]).count == 2);
    assert(summarizeClaudeStatus([ClaudeStatus.NONE]).status == ClaudeStatus.NONE);
}
