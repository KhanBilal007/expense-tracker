/**
 * Expense Tracker Google Sheet Sync Receiver
 *
 * Receives Local Data Vault JSON from the Flutter app and writes it into
 * Google Sheet tabs for backup/reporting.
 *
 * Security notes:
 * - Do not paste API keys, OAuth secrets, or service-account JSON here.
 * - Keep the deployed Web App URL private.
 * - SQLite remains the source of truth.
 * - Google Sheet is a backup/reporting copy only.
 */

const CONFIG = {
  spreadsheetId: '',
  schemaVersion: 1,
  tabs: {
    accounts: 'Accounts',
    transactions: 'Transactions',
    expenses: 'Expenses',
    moneyAdded: 'MoneyAdded',
    transfers: 'Transfers',
    summaries: 'Summaries',
    metadata: 'Metadata',
    syncLog: 'SyncLog',
  },
};

const HEADERS = {
  Accounts: ['id', 'name', 'currentBalance', 'homeOrder', 'createdDate'],
  Transactions: [
    'id',
    'account_id',
    'account_name',
    'category_id',
    'category_name',
    'amount',
    'type',
    'description',
    'date',
    'balance_after',
    'is_recurring',
    'source',
    'transaction_id',
    'dedupe_key',
  ],
  Expenses: [
    'id',
    'account_id',
    'account_name',
    'category_id',
    'category_name',
    'amount',
    'type',
    'description',
    'date',
    'source',
    'transaction_id',
    'dedupe_key',
  ],
  MoneyAdded: [
    'id',
    'account_id',
    'account_name',
    'amount',
    'type',
    'description',
    'date',
    'source',
    'transaction_id',
    'dedupe_key',
  ],
  Transfers: [
    'id',
    'from_account',
    'from_account_name',
    'to_account',
    'to_account_name',
    'amount',
    'date',
    'note',
  ],
  Summaries: ['key', 'value'],
  Metadata: ['key', 'value'],
  SyncLog: [
    'timestamp',
    'status',
    'schemaVersion',
    'accounts',
    'transactions',
    'expenses',
    'moneyAdded',
    'transfers',
    'message',
  ],
};

function doGet() {
  return jsonResponse({
    ok: true,
    service: 'expense_tracker_google_sheet_sync',
    message: 'Receiver is available. Send POST JSON from the Flutter app.',
  });
}

function doPost(e) {
  const startedAt = new Date();

  try {
    const payload = parsePayload(e);
    validatePayload(payload);

    const ss = getSpreadsheet();
    setupExpenseTrackerSheet(ss);

    writeArrayTab(ss, CONFIG.tabs.accounts, HEADERS.Accounts, payload.accounts || []);
    writeArrayTab(
      ss,
      CONFIG.tabs.transactions,
      HEADERS.Transactions,
      payload.transactions || []
    );
    writeArrayTab(ss, CONFIG.tabs.expenses, HEADERS.Expenses, payload.expenses || []);
    writeArrayTab(
      ss,
      CONFIG.tabs.moneyAdded,
      HEADERS.MoneyAdded,
      payload.moneyAdded || []
    );
    writeArrayTab(ss, CONFIG.tabs.transfers, HEADERS.Transfers, payload.transfers || []);
    writeObjectTab(ss, CONFIG.tabs.summaries, HEADERS.Summaries, payload.summaries || {});
    writeObjectTab(ss, CONFIG.tabs.metadata, HEADERS.Metadata, payload.metadata || {});

    appendSyncLog(ss, startedAt, 'success', payload, 'Synced successfully.');

    return jsonResponse({
      ok: true,
      status: 'success',
      receivedAt: startedAt.toISOString(),
      counts: getCounts(payload),
    });
  } catch (error) {
    try {
      const ss = getSpreadsheet();
      setupExpenseTrackerSheet(ss);
      appendSyncLog(ss, startedAt, 'failed', {}, safeError(error));
    } catch (logError) {
      // Avoid hiding the original receiver error if logging also fails.
    }

    return jsonResponse({
      ok: false,
      status: 'failed',
      error: safeError(error),
    });
  }
}

function setupExpenseTrackerSheet(spreadsheet) {
  const ss = spreadsheet || getSpreadsheet();
  ensureSheet(ss, CONFIG.tabs.accounts, HEADERS.Accounts);
  ensureSheet(ss, CONFIG.tabs.transactions, HEADERS.Transactions);
  ensureSheet(ss, CONFIG.tabs.expenses, HEADERS.Expenses);
  ensureSheet(ss, CONFIG.tabs.moneyAdded, HEADERS.MoneyAdded);
  ensureSheet(ss, CONFIG.tabs.transfers, HEADERS.Transfers);
  ensureSheet(ss, CONFIG.tabs.summaries, HEADERS.Summaries);
  ensureSheet(ss, CONFIG.tabs.metadata, HEADERS.Metadata);
  ensureSheet(ss, CONFIG.tabs.syncLog, HEADERS.SyncLog);
}

function parsePayload(e) {
  if (!e || !e.postData || !e.postData.contents) {
    throw new Error('Missing POST body.');
  }

  try {
    return JSON.parse(e.postData.contents);
  } catch (error) {
    throw new Error('Invalid JSON payload.');
  }
}

function validatePayload(payload) {
  if (!payload || typeof payload !== 'object') {
    throw new Error('Payload must be a JSON object.');
  }

  if (payload.schemaVersion !== CONFIG.schemaVersion) {
    throw new Error('Unsupported schemaVersion: ' + payload.schemaVersion);
  }
}

function getSpreadsheet() {
  if (CONFIG.spreadsheetId) {
    return SpreadsheetApp.openById(CONFIG.spreadsheetId);
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) {
    throw new Error('No active spreadsheet. Bind this script to a Google Sheet or set CONFIG.spreadsheetId.');
  }
  return ss;
}

function ensureSheet(ss, name, headers) {
  let sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
  }

  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  sheet.setFrozenRows(1);
  return sheet;
}

function writeArrayTab(ss, tabName, headers, rows) {
  const sheet = ensureSheet(ss, tabName, headers);
  clearDataRows(sheet, headers.length);

  if (!Array.isArray(rows) || rows.length === 0) {
    return;
  }

  const values = rows.map(function(row) {
    return headers.map(function(header) {
      return normalizeCell(row ? row[header] : '');
    });
  });

  sheet.getRange(2, 1, values.length, headers.length).setValues(values);
}

function writeObjectTab(ss, tabName, headers, obj) {
  const sheet = ensureSheet(ss, tabName, headers);
  clearDataRows(sheet, headers.length);

  const rows = flattenObject(obj || {});
  if (rows.length === 0) {
    return;
  }

  sheet.getRange(2, 1, rows.length, headers.length).setValues(rows);
}

function clearDataRows(sheet, columnCount) {
  const lastRow = sheet.getLastRow();
  if (lastRow > 1) {
    sheet.getRange(2, 1, lastRow - 1, columnCount).clearContent();
  }
}

function flattenObject(obj, prefix) {
  const rows = [];
  const base = prefix || '';

  Object.keys(obj).forEach(function(key) {
    const value = obj[key];
    const fullKey = base ? base + '.' + key : key;

    if (value && typeof value === 'object' && !Array.isArray(value)) {
      flattenObject(value, fullKey).forEach(function(row) {
        rows.push(row);
      });
    } else {
      rows.push([fullKey, normalizeCell(value)]);
    }
  });

  return rows;
}

function appendSyncLog(ss, timestamp, status, payload, message) {
  const sheet = ensureSheet(ss, CONFIG.tabs.syncLog, HEADERS.SyncLog);
  const counts = getCounts(payload || {});

  sheet.appendRow([
    timestamp.toISOString(),
    status,
    payload.schemaVersion || '',
    counts.accounts,
    counts.transactions,
    counts.expenses,
    counts.moneyAdded,
    counts.transfers,
    message || '',
  ]);
}

function getCounts(payload) {
  return {
    accounts: Array.isArray(payload.accounts) ? payload.accounts.length : 0,
    transactions: Array.isArray(payload.transactions) ? payload.transactions.length : 0,
    expenses: Array.isArray(payload.expenses) ? payload.expenses.length : 0,
    moneyAdded: Array.isArray(payload.moneyAdded) ? payload.moneyAdded.length : 0,
    transfers: Array.isArray(payload.transfers) ? payload.transfers.length : 0,
  };
}

function normalizeCell(value) {
  if (value === null || value === undefined) {
    return '';
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (typeof value === 'object') {
    return JSON.stringify(value);
  }

  return value;
}

function jsonResponse(value) {
  return ContentService.createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}

function safeError(error) {
  const message = error && error.message ? error.message : String(error);
  return message.replace(/https?:\/\/\S+/g, '[endpoint]');
}
