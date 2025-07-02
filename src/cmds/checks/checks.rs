use std::time::{Duration, Instant};

use crate::{args::PkgArgs, cmds::build_pkg::PackagePkg};
use libpacstall::pkg::keys::{DistroClamp, DistroClampError, PackageString};
use spinoff::{Color, Spinner, spinners};
use thiserror::Error;

use super::{
    deb::{DebSource, DebSourceError},
    gives::{Gives, GivesError},
    hash::{Hash, HashError},
    incompatible::{Incompatible, IncompatibleError},
    pacname::{Pacname, PacnameError},
    pkgdesc::{Pkgdesc, PkgdescError},
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

/// In order to let [`Check::Error`] have individual types, I need a meta type that enforces the
/// conversion to [`CheckError`], thus, esto.
struct ErasedCheck<T>(T);

impl<T> Check for ErasedCheck<T>
where
    T: Check,
    T::Error: Into<CheckError>,
{
    type Error = CheckError;

    fn name(&self) -> &'static str {
        self.0.name()
    }

    fn check(
        &self,
        pkgchild: &PackageString,
        handle: &PackagePkg,
        system: &DistroClamp,
    ) -> Result<(), Self::Error> {
        self.0.check(pkgchild, handle, system).map_err(Into::into)
    }
}

/// Lints for pacstall.
pub trait Check {
    /// An error that can be turned into [`CheckError`].
    type Error: Into<CheckError>;

    /// Check a particular key of a pacscript.
    ///
    /// Note that the implementor should check to determine if the package passed in is the sole
    /// package or a child package.
    ///
    /// See [`libpacstall::srcinfo::SrcInfo::is_child`] and [`libpacstall::srcinfo::SrcInfo::is_parent`].
    ///
    /// Note that `system` is nuanced-enhanced.
    fn check(
        &self,
        pkgchild: &PackageString,
        handle: &PackagePkg,
        system: &DistroClamp,
    ) -> Result<(), Self::Error>;

    /// Name of lint.
    fn name(&self) -> &'static str;
}

pub struct Checks {
    checks: Vec<Box<dyn Check<Error = CheckError>>>,
}

impl Default for Checks {
    fn default() -> Self {
        Self {
            checks: vec![
                Box::new(ErasedCheck(Pacname)),
                Box::new(ErasedCheck(Gives)),
                Box::new(ErasedCheck(Hash)),
                Box::new(ErasedCheck(DebSource)),
                Box::new(ErasedCheck(Pkgdesc)),
                Box::new(ErasedCheck(Incompatible)),
            ],
        }
    }
}

impl Checks {
    /// Run checks for pacstall.
    // Yes this is a little fancy but I like it.
    pub fn run(
        &self,
        pkgchild: &PackageString,
        handle: &PackagePkg,
        args: &PkgArgs,
    ) -> Result<(), CheckError> {
        let system = DistroClamp::system()?;

        let mut spinner = Spinner::new(
            spinners::Aesthetic,
            format!("Linting `{pkgchild}`..."),
            Color::Magenta,
        );
        let mut timings: Vec<(&str, Duration)> = vec![];

        for check in &self.checks {
            spinner.update_text(format!("Checking `{}`", check.name()));
            let instant = Instant::now();
            // The magic happens here.
            match check.check(pkgchild, handle, &system) {
                Ok(()) => {}
                Err(e) => {
                    spinner.fail(&format!("Failed linting on `{}`", check.name()));
                    return Err(e);
                }
            }
            timings.push((check.name(), instant.elapsed()));
        }

        spinner.success(&format!(
            "All lints for `{pkgchild}` passed in {}ms!",
            timings
                .iter()
                .map(|(_, time)| time)
                .sum::<Duration>()
                .as_micros()
        ));

        if std::env::var("PACSTALL_TIMINGS").is_ok() {
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
                );
            }
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
    #[error(transparent)]
    Hash(#[from] HashError),
    #[error(transparent)]
    DebSource(#[from] DebSourceError),
    #[error(transparent)]
    Pkgdesc(#[from] PkgdescError),
    #[error(transparent)]
    IncompatibleError(#[from] IncompatibleError),
    #[error(transparent)]
    DistroClampError(#[from] DistroClampError),
}
