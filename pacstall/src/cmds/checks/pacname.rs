use thiserror::Error;

use super::checks::{BashValue, Check, CheckStatus, MicroCheck, PassOrFail, impl_check};

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
            Self::no_uppercase(&input),
            "pacname uppercase",
            Some("'pacname' must not contain uppercase letters"),
            Some("url"),
            PacnameError::CaseViolation
        );

        checks
    }
}

impl Pacname {
    const fn exists(str: &str) -> bool {
        !str.is_empty()
    }

    fn two_minimum_chars(str: &str) -> (bool, usize) {
        match str.chars().collect::<Vec<_>>().len() {
            len if len < 2 => (false, len),
            good => (true, good),
        }
    }

    fn start_alphanum(str: &str) -> bool {
        str.starts_with(char::is_alphanumeric)
    }

    fn no_uppercase(str: &str) -> bool {
        str.chars().any(char::is_uppercase)
    }

    fn valid_chars(str: &str) -> bool {
        str.chars()
            .all(|c| matches!(c, 'a'..='z' | '0'..='9' | '-' | '+' | '.'))
    }
}
