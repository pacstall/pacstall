use cli_prompts::{
    DisplayPrompt,
    prompts::Confirmation,
    style::{Color, ConfirmationStyle, Formatting, LabelStyle},
};

#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum YesNo {
    Yes,
    No,
}

impl From<YesNo> for bool {
    fn from(value: YesNo) -> Self {
        match value {
            YesNo::Yes => true,
            YesNo::No => false,
        }
    }
}

/// Prompt user for a default action.
pub fn ask<I: AsRef<str>, S: Into<YesNo>>(ask: I, which: S) -> bool {
    let which = which.into();
    let confirmation_style = ConfirmationStyle {
        label_style: LabelStyle::default()
            .prefix("*")
            .prefix_formatting(Formatting::default().foreground_color(Color::Green))
            .prompt_formatting(Formatting::reset()),
        input_formatting: Formatting::default(),
        submitted_formatting: Formatting::default().bold(),
    };

    let prompt = Confirmation::new(ask.as_ref())
        .default_positive(which.into())
        .style(confirmation_style);

    match prompt.display() {
        Ok(ok) => ok,
        Err(_) => which.into(),
    }
}
