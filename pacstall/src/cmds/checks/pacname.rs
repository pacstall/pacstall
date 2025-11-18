use thiserror::Error;

use super::checks::{BashValue, Check, CheckStatus, MicroCheck, PassOrFail, impl_check};

/// `pkgname` entry/entries.
///
/// See <https://www.debian.org/doc/debian-policy/ch-controlfields.html>.
pub struct Pacname;

#[derive(Error, Debug)]
pub enum PacnameError {
    #[error("pacname is empty")]
    Empty,
    #[error("pacname is '{0}' chars long")]
    MinimumSizeViolation(usize),
    #[error("pacname contains uppercase characters")]
    CaseViolation,
}

impl Check for Pacname {
    type Err = PacnameError;

    fn check(&self, input: BashValue) -> CheckStatus<Self::Err> {
        let mut checks = CheckStatus::new();

        let input = input.decay();
        impl_check!(
            checks,
            Self::exists(&input),
            "pacname exists",
            Some("Package does not contain 'pacname'"),
            Some("url"),
            PacnameError::Empty
        );

        let (has_min_size, size) = Self::two_minimum_chars(&input);
        impl_check!(
            checks,
            has_min_size,
            "pacname size",
            Some("'pacname' must be at least two characters long"),
            Some("url"),
            PacnameError::MinimumSizeViolation(size)
        );

        impl_check!(
            checks,
            Self::is_uppercase(&input),
            "pacname uppercase",
            Some("'pacname' must not contain uppercase letters"),
            Some("url"),
            PacnameError::CaseViolation
        );

        checks
    }
}

impl Pacname {
    /// Checks that the package name is not empty.
    const fn exists(str: &str) -> bool {
        !str.is_empty()
    }

    /// Checks that the package name contains at minimum, 2 characters.
    ///
    /// Returns: `(at_least_two, len)`.
    fn two_minimum_chars(str: &str) -> (bool, usize) {
        match str.chars().collect::<Vec<_>>().len() {
            len if len < 2 => (false, len),
            good => (true, good),
        }
    }

    /// Checks that the string starts with an alphanumeric.
    ///
    /// The policy for package names is that they must start with an alphanumeric.
    fn start_alphanum(str: &str) -> bool {
        str.starts_with(char::is_alphanumeric)
    }

    /// Checks if any character is uppercase.
    ///
    /// The policy for package names is that they must not contain any uppercase letters.
    fn is_uppercase(str: &str) -> bool {
        str.chars().any(char::is_uppercase)
    }

    /// Checks for valid characters.
    ///
    /// The policy for package names is that they must consist only of lowercase letters, digits,
    /// plus (`+`), minus (`-`), and periods (`.`).
    fn valid_chars(str: &str) -> bool {
        str.chars()
            .all(|c| matches!(c, 'a'..='z' | '0'..='9' | '-' | '+' | '.'))
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn exists() {
        assert!(Pacname::exists("hello"))
    }

    #[test]
    fn not_exists() {
        assert!(!Pacname::exists(""))
    }

    #[test]
    fn below_minimum_length() {
        assert!(!Pacname::two_minimum_chars("f").0)
    }

    #[test]
    fn passes_minimum_length() {
        assert_eq!(Pacname::two_minimum_chars("foobar"), (true, 6))
    }

    #[test]
    fn starts_with_alphanumeric() {
        assert!(Pacname::start_alphanum("neofetch"))
    }

    #[test]
    fn does_not_start_with_alphanumeric() {
        assert!(!Pacname::start_alphanum("-eofetch"))
    }

    #[test]
    fn no_uppercase() {
        assert!(Pacname::is_uppercase("Pacstall"))
    }

    #[test]
    fn invalid_chars() {
        assert!(!Pacname::valid_chars("pac$tall"))
    }
}
