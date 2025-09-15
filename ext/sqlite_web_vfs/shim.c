#include <ruby.h>
#include <sqlite3.h>

// Upstream extension init symbol from mlin/sqlite_web_vfs
extern int sqlite3_webvfs_init(sqlite3 *db, char **pzErrMsg, const sqlite3_api_routines *pApi);

// Provide the default SQLite extension entry point name so Database#load_extension (1-arg)
// can load this extension into an already-open connection.
int sqlite3_extension_init(sqlite3 *db, char **pzErrMsg, const sqlite3_api_routines *pApi) {
  return sqlite3_webvfs_init(db, pzErrMsg, pApi);
}

void Init_sqlite_web_vfs(void) {
  // Register the upstream VFS as an auto-extension so it's available to all connections
  sqlite3_auto_extension((void (*)(void))sqlite3_webvfs_init);
}
