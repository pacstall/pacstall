use std::fs;

use clap::{Args, Parser, Subcommand, ValueEnum, crate_authors};

/// An AUR inspired package manager for Ubuntu.
#[derive(Parser)]
#[command(author = crate_authors!(), version = Arguments::version("radiance"), about, next_line_help = true)]
pub struct Arguments {
    #[command(subcommand)]
    pub command: Commands,
}

impl Arguments {
    pub fn version(version: &str) -> String {
        format!(
            "{} {} {}",
            env!("CARGO_PKG_VERSION"),
            version,
            fs::read_to_string("/usr/share/pacstall/repo/update")
                .unwrap_or("pacstall master".to_string())
                .trim()
        )
    }
}

#[derive(Subcommand)]
pub enum Commands {
    /// Install a package.
    Install {
        /// Package or pacscript to install.
        package: String,

        #[command(flatten)]
        args: PkgArgs,
    },
    /// Build a package.
    Build {
        /// Package or pacscript to install.
        package: String,

        #[command(flatten)]
        args: PkgArgs,
    },
    /// Search for a package.
    Search {
        /// Package to search for.
        package: String,
    },
    /// Remove a package.
    Remove {
        /// Package to remove.
        package: String,
    },
    /// Download a pacscript.
    Download {
        /// Package to download.
        package: String,
    },
    /// Manipulate repositories.
    #[command(subcommand)]
    Repo(RepoCommands),
    /// List all installed packages.
    List,
    /// Upgrade all installed packages.
    Upgrade,
    /// Query information about an installed package.
    Info {
        /// Package to query.
        package: String,

        /// Key to print out.
        key: Option<String>,
    },
    /// Mark upgrade checking of an installed package.
    Mark {
        /// Package to mark.
        package: String,

        #[arg(value_enum)]
        operation: HoldOperation,
    },
    /// Display a tree graph of an installed packages files.
    Tree {
        /// Package to print.
        package: String,
    },
}

/// Flags only available for building packages.
#[derive(Debug, Args)]
pub struct PkgArgs {
    /// Enable debug output.
    #[arg(short = 'x', long)]
    debug: bool,

    /// Disable prompts.
    #[arg(short = 'P', long)]
    disable_prompts: bool,

    /// Keep the build files after building.
    #[arg(short = 'K', long)]
    keep: bool,

    /// Skip the `check()` function if present.
    #[arg(short = 'N', long)]
    nocheck: bool,

    /// Download package entries quietly.
    #[arg(short = 'Q', long)]
    quiet: bool,
}

/// Repository manipulation commands.
#[derive(Debug, Subcommand)]
pub enum RepoCommands {
    /// Add a repository.
    Add {
        /// Repository link.
        link: String,
    },
    /// Remove a repository.
    Remove {
        /// Repository link or alias.
        link: String,
    },
}

/// Hold or unhold package.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, ValueEnum)]
pub enum HoldOperation {
    /// Hold package.
    Hold,
    /// Unhold package.
    Unhold,
}
