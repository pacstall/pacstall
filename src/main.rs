mod args;
mod utilities;

use args::{Arguments, Commands};
use clap::Parser;

fn main() {
    match Arguments::parse().command {
        Commands::List => fancy_message!(Error, "{}", "Working on it"),
        Commands::Upgrade => todo!(),
        Commands::Repo(_) => todo!(),
        Commands::Info { package, key } => todo!(),
        Commands::Tree { package } => todo!(),
        Commands::Build { package, args } => todo!(),
        Commands::Search { package } => todo!(),
        Commands::Remove { package } => todo!(),
        Commands::Install { package, args } => todo!(),
        Commands::Download { package } => todo!(),
        Commands::Mark { package, operation } => todo!(),
    }
}
