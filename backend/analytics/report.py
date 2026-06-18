"""
PDF report builder for UC09 Generate Report.

Renders the same KPIs + charts as the admin Analytics dashboard into a
single A4 PDF using reportlab's native drawing (no matplotlib dep).
"""

from datetime import datetime
from io import BytesIO

from reportlab.graphics.charts.barcharts import HorizontalBarChart, VerticalBarChart
from reportlab.graphics.charts.lineplots import LinePlot
from reportlab.graphics.shapes import Drawing, String
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from analytics import services


UTM_CRIMSON = colors.HexColor("#8B1A2B")
UTM_RED = colors.HexColor("#D42A2A")
INK = colors.HexColor("#1E1E1E")
MUTED = colors.HexColor("#6B6B6B")
PAPER = colors.HexColor("#F7F7F8")


def _styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "title", parent=base["Title"], fontSize=22, leading=26,
            textColor=UTM_CRIMSON, alignment=0, spaceAfter=4,
        ),
        "subtitle": ParagraphStyle(
            "subtitle", parent=base["Normal"], fontSize=11,
            textColor=MUTED, spaceAfter=18,
        ),
        "h2": ParagraphStyle(
            "h2", parent=base["Heading2"], fontSize=14, leading=18,
            textColor=INK, spaceBefore=12, spaceAfter=8,
        ),
        "body": ParagraphStyle(
            "body", parent=base["Normal"], fontSize=10, leading=14,
            textColor=INK,
        ),
        "small": ParagraphStyle(
            "small", parent=base["Normal"], fontSize=8, leading=10,
            textColor=MUTED,
        ),
    }


def _kpi_table(overview: dict) -> Table:
    rows = [
        ["Riders (last 24h)", f"{overview['riders_last_24h']:,}"],
        ["Active buses", f"{overview['buses_active']} / {overview['buses_total']}"],
        ["Active routes", f"{overview['routes_active']} / {overview['routes_total']}"],
        [
            "Open feedback",
            f"{overview['feedback_new'] + overview['feedback_in_progress']} / {overview['feedback_total']}",
        ],
    ]
    table = Table(rows, colWidths=[8 * cm, 4 * cm])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), PAPER),
        ("TEXTCOLOR", (0, 0), (0, -1), INK),
        ("TEXTCOLOR", (1, 0), (1, -1), UTM_CRIMSON),
        ("FONTNAME", (0, 0), (0, -1), "Helvetica"),
        ("FONTNAME", (1, 0), (1, -1), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 11),
        ("ALIGN", (1, 0), (1, -1), "RIGHT"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("LINEBELOW", (0, 0), (-1, -2), 0.4, colors.lightgrey),
    ]))
    return table


def _line_chart(points: list[dict], x_key: str, y_key: str, title: str) -> Drawing:
    drawing = Drawing(16 * cm, 7 * cm)
    drawing.add(String(0, 6.4 * cm, title, fontSize=11, fillColor=INK))

    plot = LinePlot()
    plot.x = 30
    plot.y = 20
    plot.width = 16 * cm - 50
    plot.height = 5.4 * cm

    data = [(i, p[y_key]) for i, p in enumerate(points)]
    plot.data = [data]
    plot.lines[0].strokeColor = UTM_CRIMSON
    plot.lines[0].strokeWidth = 1.6

    max_y = max((p[y_key] for p in points), default=0) or 1
    plot.yValueAxis.valueMin = 0
    plot.yValueAxis.valueMax = max_y * 1.15
    plot.yValueAxis.labels.fontSize = 7
    plot.yValueAxis.labels.fillColor = MUTED

    plot.xValueAxis.valueMin = 0
    plot.xValueAxis.valueMax = max(len(points) - 1, 1)
    # X labels every ~5 days for readability
    step = max(1, len(points) // 6)
    plot.xValueAxis.valueSteps = list(range(0, len(points), step))
    plot.xValueAxis.labelTextFormat = lambda i: (
        points[int(i)][x_key][-5:] if 0 <= int(i) < len(points) else ""
    )
    plot.xValueAxis.labels.fontSize = 7
    plot.xValueAxis.labels.fillColor = MUTED

    drawing.add(plot)
    return drawing


def _bar_chart_vertical(points: list[dict], x_key: str, y_key: str, title: str) -> Drawing:
    drawing = Drawing(16 * cm, 7 * cm)
    drawing.add(String(0, 6.4 * cm, title, fontSize=11, fillColor=INK))

    bc = VerticalBarChart()
    bc.x = 30
    bc.y = 20
    bc.width = 16 * cm - 50
    bc.height = 5.4 * cm
    bc.data = [[p[y_key] for p in points]]
    bc.categoryAxis.categoryNames = [str(p[x_key]) for p in points]
    bc.categoryAxis.labels.fontSize = 7
    bc.categoryAxis.labels.fillColor = MUTED
    bc.valueAxis.valueMin = 0
    bc.valueAxis.labels.fontSize = 7
    bc.valueAxis.labels.fillColor = MUTED
    bc.bars[0].fillColor = UTM_RED
    bc.bars[0].strokeColor = UTM_RED
    bc.barWidth = 4
    drawing.add(bc)
    return drawing


def _bar_chart_horizontal(points: list[dict], label_key: str, value_key: str, title: str) -> Drawing:
    drawing = Drawing(16 * cm, max(7 * cm, len(points) * 0.7 * cm))
    drawing.add(String(0, drawing.height - 0.6 * cm, title, fontSize=11, fillColor=INK))

    bc = HorizontalBarChart()
    bc.x = 90
    bc.y = 20
    bc.width = 16 * cm - 110
    bc.height = drawing.height - 1.6 * cm
    bc.data = [[p[value_key] for p in points]]
    bc.categoryAxis.categoryNames = [p[label_key][:30] for p in points]
    bc.categoryAxis.labels.fontSize = 7
    bc.categoryAxis.labels.fillColor = INK
    bc.valueAxis.valueMin = 0
    bc.valueAxis.labels.fontSize = 7
    bc.valueAxis.labels.fillColor = MUTED
    bc.bars[0].fillColor = UTM_CRIMSON
    bc.bars[0].strokeColor = UTM_CRIMSON
    drawing.add(bc)
    return drawing


def _stops_table(points: list[dict]) -> Table:
    rows = [["#", "Stop", "Riders (30d)"]]
    for i, p in enumerate(points, start=1):
        rows.append([str(i), p["stop_name"], f"{p['riders']:,}"])
    table = Table(rows, colWidths=[1 * cm, 11 * cm, 4 * cm])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), UTM_CRIMSON),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("ALIGN", (0, 0), (0, -1), "CENTER"),
        ("ALIGN", (2, 0), (2, -1), "RIGHT"),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PAPER]),
        ("LINEBELOW", (0, 0), (-1, -1), 0.3, colors.lightgrey),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return table


def _header_footer(canvas, doc):
    canvas.saveState()
    # Header crimson rule
    canvas.setStrokeColor(UTM_CRIMSON)
    canvas.setLineWidth(2)
    canvas.line(2 * cm, A4[1] - 1.2 * cm, A4[0] - 2 * cm, A4[1] - 1.2 * cm)
    # Footer
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(2 * cm, 1.2 * cm, "UTM BusTracker — Analytics Report")
    canvas.drawRightString(A4[0] - 2 * cm, 1.2 * cm, f"Page {doc.page}")
    canvas.restoreState()


def build_report(days: int = 30) -> bytes:
    """Generate the analytics report and return the PDF as bytes."""
    overview = services.overview()
    ridership_daily = services.ridership_daily(days)
    ridership_hourly = services.ridership_by_hour()
    demand = services.demand_by_stop(10)
    feedback = services.feedback_daily(days)

    styles = _styles()
    buf = BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=2 * cm,
        rightMargin=2 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
        title="UTM BusTracker — Analytics Report",
        author="UTM BusTracker",
    )

    story = []
    story.append(Paragraph("UTM BusTracker", styles["title"]))
    story.append(Paragraph(
        f"Analytics report — generated {datetime.now().strftime('%d %b %Y, %H:%M')} "
        f"&nbsp;·&nbsp; window: last {days} days",
        styles["subtitle"],
    ))

    story.append(Paragraph("Overview", styles["h2"]))
    story.append(_kpi_table(overview))
    story.append(Spacer(1, 0.6 * cm))

    story.append(Paragraph("Ridership — daily", styles["h2"]))
    story.append(_line_chart(ridership_daily, "date", "riders",
                             f"Total riders per day (last {days} days)"))
    story.append(Spacer(1, 0.4 * cm))

    story.append(Paragraph("Peak hours", styles["h2"]))
    story.append(_bar_chart_vertical(ridership_hourly, "hour", "avg_riders",
                                     "Average riders by hour of day"))
    story.append(PageBreak())

    story.append(Paragraph("Top stops by demand", styles["h2"]))
    if demand:
        story.append(_bar_chart_horizontal(demand, "stop_name", "riders",
                                           f"Riders per stop (last {days} days)"))
        story.append(Spacer(1, 0.3 * cm))
        story.append(_stops_table(demand))
    else:
        story.append(Paragraph(
            "No ridership data yet. Seed with "
            "<font face='Courier'>python manage.py seed_data_logs</font>.",
            styles["body"],
        ))
    story.append(Spacer(1, 0.6 * cm))

    story.append(Paragraph("Feedback submissions", styles["h2"]))
    story.append(_line_chart(feedback, "date", "count",
                             f"Submissions per day (last {days} days)"))
    story.append(Spacer(1, 0.4 * cm))

    fb_summary = Table(
        [
            ["New", "In progress", "Resolved", "Total"],
            [
                str(overview["feedback_new"]),
                str(overview["feedback_in_progress"]),
                str(overview["feedback_resolved"]),
                str(overview["feedback_total"]),
            ],
        ],
        colWidths=[4 * cm] * 4,
    )
    fb_summary.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), PAPER),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("TEXTCOLOR", (0, 1), (-1, 1), UTM_CRIMSON),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("LINEBELOW", (0, 0), (-1, -1), 0.3, colors.lightgrey),
    ]))
    story.append(fb_summary)

    doc.build(story, onFirstPage=_header_footer, onLaterPages=_header_footer)
    return buf.getvalue()
