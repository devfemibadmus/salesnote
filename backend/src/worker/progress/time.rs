use chrono::{DateTime, Datelike, LocalResult, NaiveDate, TimeZone};
use chrono_tz::Tz;

pub fn local_midnight(tz: Tz, date: NaiveDate) -> DateTime<Tz> {
    match tz.with_ymd_and_hms(date.year(), date.month(), date.day(), 0, 0, 0) {
        LocalResult::Single(dt) => dt,
        LocalResult::Ambiguous(dt, _) => dt,
        LocalResult::None => tz
            .with_ymd_and_hms(date.year(), date.month(), date.day(), 1, 0, 0)
            .single()
            .expect("failed to resolve timezone midnight"),
    }
}
