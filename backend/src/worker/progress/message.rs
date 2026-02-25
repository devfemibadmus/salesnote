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
            "Last {} at this time you had {} sales.",
            input.period_label, input.previous_sales
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
            "Last {} at this time you had 0 sales. This {} you have {}.",
            input.period_label, input.period_label, input.current_sales
        );
        if let Some(line) = top_line {
            body.push_str(&format!("\n{}", line));
        }
        return Some(NotificationMessage {
            title: format!("Great start this {}", input.period_label),
            body,
        });
    }

    let percent =
        ((input.previous_sales as f64) / (input.current_sales as f64) * 100.0).round() as i64;
    let mut body = format!(
        "This time last {} you were making {}% of what you're making this {}. Last {}: {} sales. This {}: {} sales.",
        input.period_label,
        percent,
        input.period_label,
        input.period_label,
        input.previous_sales,
        input.period_label,
        input.current_sales
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
