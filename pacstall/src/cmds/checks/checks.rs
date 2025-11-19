use std::{
    collections::BTreeMap,
    error::Error,
    ops::{Deref, DerefMut, RangeInclusive},
};

/// A wrapper for a [`String`] that includes a source span.
///
/// This should behave exactly like a string does, and any difference in behavior should be
/// considered a bug.
#[derive(Clone, Eq)]
pub struct StringSpan {
    string: String,
    span: RangeInclusive<usize>,
}

impl PartialEq for StringSpan {
    fn eq(&self, other: &Self) -> bool {
        self.string.eq(&other.string)
    }
}

impl PartialOrd for StringSpan {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        self.string.partial_cmp(&other.string)
    }
}

impl Ord for StringSpan {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.string.cmp(&other.string)
    }
}

impl Default for StringSpan {
    fn default() -> Self {
        Self {
            string: String::new(),
            span: 0..=0,
        }
    }
}

impl Deref for StringSpan {
    type Target = String;

    fn deref(&self) -> &Self::Target {
        &self.string
    }
}

impl DerefMut for StringSpan {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.string
    }
}

impl From<String> for StringSpan {
    fn from(value: String) -> Self {
        Self {
            span: 0..=value.len(),
            string: value,
        }
    }
}

impl StringSpan {
    pub fn new(string: String, span: RangeInclusive<usize>) -> Self {
        Self { string, span }
    }

    pub fn span(&self) -> &RangeInclusive<usize> {
        &self.span
    }
}

/// All relevant bash types that a pacstall key can be.
pub enum BashValue {
    /// A single string.
    ///
    /// ```bash
    /// foo="bar"
    /// ```
    String(StringSpan),
    /// An associated array.
    ///
    /// ```bash
    /// foo=([a]="here is a" [b]="here is b")
    /// ```
    AssociatedArray(BTreeMap<StringSpan, StringSpan>),
    /// An index array.
    ///
    /// ```bash
    /// foo=(1 2 3)
    /// ```
    IndexedArray(BTreeMap<u64, StringSpan>),
}

impl BashValue {
    /// Decay arrays into their first element.
    ///
    /// Equivalent to:
    ///
    /// ```bash
    /// foo=(bar baz bing)
    /// my_bar="${foo}" # Is now `bar`
    /// ```
    #[must_use = "return value should be considered or else there is no point in decaying"]
    pub fn decay(self) -> StringSpan {
        match self {
            Self::String(s) => s,
            Self::AssociatedArray(elems) => {
                let first = elems.iter().map(|s| s.0).min_by_key(|&s| s.span.start());
                match first {
                    Some(first) => elems.get(first).cloned().unwrap_or_default(),
                    None => StringSpan::default(),
                }
            }
            Self::IndexedArray(elems) => {
                let lowest = elems.iter().map(|s| s.0).min();
                match lowest {
                    Some(lowest) => elems.get(lowest).cloned().unwrap_or_default(),
                    None => StringSpan::default(),
                }
            }
        }
    }
}

/// Has a [`MicroCheck`] passed or failed?
#[derive(Copy, Clone, PartialEq, Eq)]
pub enum PassOrFail<E> {
    Pass,
    Fail(E),
}

/// Contains a subcheck that the [`CheckStatus`] holds.
///
/// For instance, a check for value "$FOO" could have checks for both the
/// length and the capitalization rules of the value. Both of those would
/// be a [`MicroCheck`].
pub struct MicroCheck<E> {
    name: &'static str,
    desc: Option<&'static str>,
    help_link: Option<&'static str>,
    status: PassOrFail<E>,
}

/// Status of a given check run.
pub struct CheckStatus<E> {
    passes: Vec<MicroCheck<E>>,
}

impl<E> MicroCheck<E> {
    pub fn name(&self) -> &'static str {
        self.name
    }

    pub fn desc(&self) -> Option<&'static str> {
        self.desc
    }

    pub fn help_link(&self) -> Option<&'static str> {
        self.help_link
    }

    pub const fn failed(&self) -> bool {
        matches!(self.status, PassOrFail::Fail(_))
    }

    pub const fn passed(&self) -> bool {
        matches!(self.status, PassOrFail::Pass)
    }

    pub const fn pass_type(&self) -> PassType {
        match self.status {
            PassOrFail::Pass => PassType::Passing,
            PassOrFail::Fail(_) => PassType::Failing,
        }
    }

    pub fn new(
        name: &'static str,
        desc: Option<&'static str>,
        help_link: Option<&'static str>,
        status: PassOrFail<E>,
    ) -> Self {
        Self {
            name,
            desc,
            status,
            help_link,
        }
    }
}

/// Which [`PassOrFail`] branch is hit?
///
/// See [`CheckStatus::filter_type`].
#[derive(Copy, Clone, PartialEq, Eq)]
pub enum PassType {
    Passing,
    Failing,
}

impl<E> From<PassOrFail<E>> for PassType {
    fn from(value: PassOrFail<E>) -> Self {
        match value {
            PassOrFail::Pass => Self::Passing,
            PassOrFail::Fail(_) => Self::Failing,
        }
    }
}

impl<E> CheckStatus<E> {
    pub const fn new() -> Self {
        Self { passes: vec![] }
    }

    pub fn name(&self, idx: usize) -> Option<&str> {
        self.passes.get(idx).map(MicroCheck::name)
    }

    pub const fn len(&self) -> usize {
        self.passes.len()
    }

    pub const fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Determine whether a check has failed to complete all of its subchecks.
    pub fn has_error(&self) -> bool {
        self.passes.iter().any(MicroCheck::failed)
    }

    /// Filter out a list based on a predicate.
    ///
    /// See [`PassType`].
    pub fn filter_type(&self, pass_type: PassType) -> impl Iterator<Item = &MicroCheck<E>> {
        self.passes.iter().filter(move |pass| match pass_type {
            PassType::Passing => pass.passed(),
            PassType::Failing => pass.failed(),
        })
    }

    /// Push a check into the status.
    pub fn push(&mut self, chk: MicroCheck<E>) {
        self.passes.push(chk);
    }
}

/// Implement an umbrella of checks for a given input.
pub trait Check {
    /// The check's error type.
    type Err: Error;

    /// Run check(s) and report their pass/fail status.
    ///
    /// It's generally a good idea to have many individual subchecks that compose this [`Check::check`]. Try to keep subchecks as small as possible. Bonus points if they return a bool, so they can be easily unit tested.
    fn check(&self, input: BashValue) -> CheckStatus<Self::Err>;
}

/// Convenience wrapper for adding [`MicroCheck`]s to the [`CheckStatus`] array.
#[macro_export]
macro_rules! impl_check {
    ($checks:ident, $check:expr, $name:expr, $desc:expr, $help:expr, $error:expr) => {
        $checks.push(MicroCheck::new(
            $name,
            $desc,
            $help,
            if $check {
                PassOrFail::Pass
            } else {
                PassOrFail::Fail($error)
            },
        ))
    };
}

pub(super) use impl_check;
