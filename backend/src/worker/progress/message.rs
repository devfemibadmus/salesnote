use chrono::{DateTime, Datelike, Duration, TimeZone};

pub struct NotificationMessage {
    pub title: String,
    pub body: String,
}

pub struct TopItem {
    pub name: String,
    pub quantity: f64,
}

pub struct ProgressInput {
    pub period_label: &'static str,
    pub comparison_reference: String,
    pub current_sales: i64,
    pub previous_sales: i64,
    pub top_item: Option<TopItem>,
}

pub fn build_progress_message(input: ProgressInput) -> Option<NotificationMessage> {
    if input.current_sales == 0 && input.previous_sales == 0 {
        return None;
    }

    let top_line = input.top_item.as_ref().map(|item| {
        let qty = format_quantity(item.quantity);
        format!("Top item: {} ({} sold)", item.name, qty)
    });

    if input.current_sales == 0 {
        let mut body = format!(
            "{} you had {} sales.",
            input.comparison_reference, input.previous_sales
        );
        if let Some(line) = top_line {
            body.push_str(&format!("\n{}", line));
        }
        return Some(NotificationMessage {
            title: format!("No sales yet this {}", input.period_label),
            body,
        });
    }

    if input.previous_sales == 0 {
        let mut body = format!(
            "{} you had 0 sales. This {} you have {}.",
            input.comparison_reference, input.period_label, input.current_sales
        );
        if let Some(line) = top_line {
            body.push_str(&format!("\n{}", line));
        }
        return Some(NotificationMessage {
            title: format!("Great start this {}", input.period_label),
            body,
        });
    }

    let change_pct = (((input.current_sales - input.previous_sales) as f64)
        / (input.previous_sales as f64)
        * 100.0)
        .round() as i64;
    let comparison = if change_pct >= 0 {
        format!("That is {}% more.", change_pct)
    } else {
        format!("That is {}% less.", change_pct.abs())
    };
    let mut body = format!(
        "{} you had {} sales. This {} you have {}. {}",
        input.comparison_reference,
        input.previous_sales,
        input.period_label,
        input.current_sales,
        comparison,
    );
    if let Some(line) = top_line {
        body.push_str(&format!("\n{}", line));
    }

    Some(NotificationMessage {
        title: format!("{} sales pace", capitalize(input.period_label)),
        body,
    })
}

fn format_quantity(value: f64) -> String {
    if (value.fract() - 0.0).abs() < f64::EPSILON {
        format!("{}", value as i64)
    } else {
        format!("{:.2}", value)
    }
}

fn capitalize(input: &str) -> String {
    let mut chars = input.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}

pub fn format_comparison_reference<Tz: TimeZone>(
    now_local: DateTime<Tz>,
    comparison_local: DateTime<Tz>,
) -> String
where
    Tz::Offset: std::fmt::Display,
{
    if comparison_local.date_naive() == now_local.date_naive() - Duration::days(1) {
        return String::from("Yesterday at this time");
    }

    format!(
        "On {} {} of {} at this time",
        comparison_local.format("%A"),
        ordinal(comparison_local.day()),
        comparison_local.format("%B"),
    )
}

fn ordinal(day: u32) -> String {
    let suffix = match day % 100 {
        11 | 12 | 13 => "th",
        _ => match day % 10 {
            1 => "st",
            2 => "nd",
            3 => "rd",
            _ => "th",
        },
    };
    format!("{}{}", day, suffix)
}
