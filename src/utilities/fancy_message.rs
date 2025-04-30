use std::fmt::Display;

#[macro_export]
macro_rules! fancy_message {
    ($type:ident, $($arg:tt)*) => {{
        let formatted = format!($($arg)*);
        match $crate::utilities::fancy_message::FancyMessageType::$type {
            $crate::utilities::fancy_message::FancyMessageType::Info | $crate::utilities::fancy_message::FancyMessageType::Sub => println!("{} {formatted}", $crate::utilities::fancy_message::FancyMessageType::$type),
            other => eprintln!("{} {formatted}", other),
        }
    }};
}

#[derive(PartialEq, Eq)]
pub enum FancyMessageType {
    Info,
    Warn,
    Error,
    Sub,
    Unknown,
}

impl Display for FancyMessageType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match self {
                Self::Info => "[\x1b[32m+\x1b[0m] \x1b[1mINFO\x1b[0m:",
                Self::Warn => "[\x1b[33m*\x1b[0m] \x1b[1mWARNING\x1b[0m:",
                Self::Error => "[\x1b[31m!\x1b[0m] \x1b[1mERROR\x1b[0m:",
                Self::Sub => "\t[\x1b[34m>\x1b[0m]",
                Self::Unknown => "[\x1b[1m?\x1b[0m] \x1b[1mUNKNOWN\x1b[0m:",
            }
        )
    }
}
