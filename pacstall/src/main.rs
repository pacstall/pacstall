#![allow(dead_code)] // While we finish the plumbing

mod args;
mod cmds;

use args::{Arguments, Commands};
use clap::Parser;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    match Arguments::parse().command {
        Commands::List => todo!(),
        Commands::Upgrade => todo!(),
        Commands::Repo(_) => todo!(),
        Commands::Info { package: _, key: _ } => todo!(),
        Commands::Tree { package: _ } => todo!(),
        Commands::Build {
            package: _,
            args: _,
        } => todo!(),
        Commands::Search { package: _ } => todo!(),

        Commands::Remove { package: _ } => todo!(),
        Commands::Install {
            package: _,
            args: _,
        } => todo!(),
        Commands::Download { package: _ } => todo!(),
        Commands::Mark {
            package: _,
            operation: _,
        } => todo!(),
    }

    // Ok(())
}
