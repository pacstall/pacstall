use std::{
    env,
    process::{Command, ExitStatus},
};

/// Edit a file.
///
/// Takes from the following sources for finding editors:
///
/// 1. `$PACSTALL_EDITOR`
/// 2. `$EDITOR`
/// 3. `$VISUAL`
/// 4. `sensible-editor`
pub fn editor<S: AsRef<str>>(path: S) -> std::io::Result<ExitStatus> {
    let path = path.as_ref();
    match (
        env::var("PACSTALL_EDITOR"),
        env::var("EDITOR"),
        env::var("VISUAL"),
    ) {
        (Ok(editor), _, _) | (_, Ok(editor), _) | (_, _, Ok(editor)) => {
            Command::new(editor).arg(path).status()
        }
        _ => Command::new("sensible-editor").arg(path).status(),
    }
}
