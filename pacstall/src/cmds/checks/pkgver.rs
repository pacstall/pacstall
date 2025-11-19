use thiserror::Error;

use super::checks::{BashValue, Check, CheckStatus, MicroCheck, PassOrFail, impl_check};

/// `pkgver` entry/entries.
///
/// See <https://www.debian.org/doc/debian-policy/ch-controlfields.html#version>.
pub struct Pkgver;

#[derive(Error, Debug)]
pub enum PkgverError {
    #[error("pkgver has invalid chars")]
    InvalidChars,
    #[error("pkgver does not start with a digit")]
    NoStartingDigit,
}

impl Check for Pkgver {
    type Err = PkgverError;

    fn check(&self, input: BashValue) -> CheckStatus<Self::Err> {
        let mut checks = CheckStatus::new();

        let input = input.decay();

        impl_check!(
            checks,
            Self::starts_with_digit(&input),
            "pkgver starts with digit",
            Some("`pkgver` does not start with a digit"),
            Some("url"),
            Self::Err::NoStartingDigit
        );

        impl_check!(
            checks,
            Self::valid_chars(&input),
            "pkgver has only valid chars",
            Some("`pkgver` contains invalid characters"),
            Some("url"),
            Self::Err::InvalidChars
        );

        checks
    }
}

impl Pkgver {
    fn starts_with_digit(str: &str) -> bool {
        str.starts_with(|c: char| c.is_ascii_digit())
    }

    /// Checks for valid characters.
    ///
    /// The policy states that `pkgver` must only contain alphanumerics and the characters `.`,
    /// `+`, `-`, `~`.
    fn valid_chars(str: &str) -> bool {
        str.chars()
            .all(|c| matches!(c, 'a'..='z' | 'A'..='Z' | '0'..='9' | '-' | '+' | '.' | '~'))
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn starts_with_digit() {
        assert!(Pkgver::starts_with_digit("0.1.2"))
    }

    #[test]
    fn correctly_fails_on_non_digit() {
        assert!(!Pkgver::starts_with_digit("a.1.2"))
    }

    #[test]
    fn invalid_chars() {
        assert!(!Pkgver::valid_chars("$.1.2"))
    }
}
