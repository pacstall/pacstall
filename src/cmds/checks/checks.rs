use std::time::{Duration, Instant};

use crate::cmds::build_pkg::PackagePkg;
use libpacstall::pkg::keys::PackageString;
use spinoff::{Color, Spinner, spinners};
use thiserror::Error;

use super::{
    gives::{Gives, GivesError},
    pacname::{Pacname, PacnameError},
};

/// Simple wrapper for if then return error.
#[macro_export]
macro_rules! fail_if {
    ($expr:expr => $err:expr) => {
        if $expr {
            return Err($err);
        }
    };
}

/// Lints for pacstall.
pub trait Check {
    /// Check a particular key of a pacscript.
    fn check(&self, pkgchild: &PackageString, handle: &PackagePkg) -> Result<(), CheckError>;

    /// Name of lint.
    fn name(&self) -> &'static str;
}

pub struct Checks {
    checks: Vec<Box<dyn Check>>,
}

impl Default for Checks {
    fn default() -> Self {
        Self {
            checks: vec![Box::new(Pacname), Box::new(Gives)],
        }
    }
}

impl Checks {
    /// Run checks for pacstall.
    // Yes this is a little fancy but I like it.
    pub fn run(&self, pkgchild: &PackageString, handle: &PackagePkg) -> Result<(), CheckError> {
        let mut spinner = Spinner::new(spinners::Aesthetic, "Linting pacscript...", Color::Green);
        let mut timings: Vec<(&str, Duration)> = vec![];

        for check in &self.checks {
            spinner.update_text(format!("Checking `{}`", check.name()));
            let instant = Instant::now();
            check.check(pkgchild, handle)?;
            timings.push((check.name(), instant.elapsed()));
        }

        spinner.success("All lints passed!");

        println!(">>> Timings Report <<<");
        let max_width = timings
            .iter()
            .map(|(label, _)| label.len())
            .max()
            .unwrap_or(0);
        for (label, time) in timings {
            println!(
                "    {: <width$} -> {}ms",
                label,
                time.as_micros(),
                width = max_width
            )
        }

        Ok(())
    }
}

#[derive(Debug, Error)]
pub enum CheckError {
    #[error(transparent)]
    Pacname(#[from] PacnameError),

    #[error(transparent)]
    Gives(#[from] GivesError),
}
