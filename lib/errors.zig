// ╔══════════════════════════════════════ Errors ══════════════════════════════════════╗

// ┌──────────────────────────── ParseError ────────────────────────────┐

pub const ParseError = error{
    InvalidFormat,
    InvalidTimestamp,
    InvalidOpen,
    InvalidHigh,
    InvalidLow,
    InvalidClose,
    InvalidVolume,
    InvalidDateFormat,
    DateBeforeEpoch,
    OutOfMemory,
    EndOfStream,
};

// └──────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── FetchError ────────────────────────────┐

pub const FetchError = error{HttpError} || ParseError;

// └──────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════╝
