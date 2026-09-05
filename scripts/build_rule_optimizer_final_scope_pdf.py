from __future__ import annotations

from pathlib import Path
from typing import Iterable

from reportlab.graphics.shapes import Drawing, Line, Polygon, Rect, String
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Flowable,
    Frame,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "pdf" / "EFRM_Rule_Optimization_Agent_Final_Fixed_Scope_and_Workflow.pdf"

PAGE_W, PAGE_H = A4
MARGIN_X = 15 * mm
MARGIN_TOP = 17 * mm
MARGIN_BOTTOM = 15 * mm
CONTENT_W = PAGE_W - 2 * MARGIN_X

NAVY = colors.HexColor("#102A43")
BLUE = colors.HexColor("#176B87")
TEAL = colors.HexColor("#1F8A70")
CYAN = colors.HexColor("#DFF4F1")
LIGHT_BLUE = colors.HexColor("#EAF3F8")
LIGHT_TEAL = colors.HexColor("#E8F5F1")
AMBER = colors.HexColor("#F3A712")
LIGHT_AMBER = colors.HexColor("#FFF4D8")
RED = colors.HexColor("#C84630")
LIGHT_RED = colors.HexColor("#FCEAE6")
INK = colors.HexColor("#23323F")
MUTED = colors.HexColor("#617181")
LINE = colors.HexColor("#C9D5DE")
PALE = colors.HexColor("#F6F9FB")
WHITE = colors.white


def styles():
    s = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "Title", parent=s["Title"], fontName="Helvetica-Bold", fontSize=25,
            leading=30, textColor=WHITE, alignment=TA_LEFT, spaceAfter=5 * mm,
        ),
        "subtitle": ParagraphStyle(
            "Subtitle", parent=s["Normal"], fontName="Helvetica", fontSize=11,
            leading=16, textColor=colors.HexColor("#DCEBF2"), spaceAfter=3 * mm,
        ),
        "h1": ParagraphStyle(
            "H1", parent=s["Heading1"], fontName="Helvetica-Bold", fontSize=18,
            leading=22, textColor=NAVY, spaceBefore=1 * mm, spaceAfter=4 * mm,
        ),
        "h2": ParagraphStyle(
            "H2", parent=s["Heading2"], fontName="Helvetica-Bold", fontSize=13,
            leading=17, textColor=BLUE, spaceBefore=3 * mm, spaceAfter=2 * mm,
        ),
        "body": ParagraphStyle(
            "Body", parent=s["BodyText"], fontName="Helvetica", fontSize=9.2,
            leading=13.1, textColor=INK, spaceAfter=2.2 * mm,
        ),
        "small": ParagraphStyle(
            "Small", parent=s["BodyText"], fontName="Helvetica", fontSize=7.3,
            leading=9.6, textColor=INK,
        ),
        "tiny": ParagraphStyle(
            "Tiny", parent=s["BodyText"], fontName="Helvetica", fontSize=6.4,
            leading=8.2, textColor=INK,
        ),
        "table_head": ParagraphStyle(
            "TableHead", parent=s["BodyText"], fontName="Helvetica-Bold", fontSize=7.1,
            leading=8.8, textColor=WHITE, alignment=TA_LEFT,
        ),
        "table": ParagraphStyle(
            "Table", parent=s["BodyText"], fontName="Helvetica", fontSize=6.7,
            leading=8.6, textColor=INK,
        ),
        "table_bold": ParagraphStyle(
            "TableBold", parent=s["BodyText"], fontName="Helvetica-Bold", fontSize=6.8,
            leading=8.6, textColor=NAVY,
        ),
        "callout": ParagraphStyle(
            "Callout", parent=s["BodyText"], fontName="Helvetica-Bold", fontSize=10,
            leading=14, textColor=NAVY, spaceAfter=0,
        ),
        "bullet": ParagraphStyle(
            "Bullet", parent=s["BodyText"], fontName="Helvetica", fontSize=8.7,
            leading=12.2, textColor=INK, leftIndent=4 * mm, firstLineIndent=-3 * mm,
            bulletIndent=0, spaceAfter=1.2 * mm,
        ),
        "caption": ParagraphStyle(
            "Caption", parent=s["BodyText"], fontName="Helvetica-Oblique", fontSize=7.3,
            leading=9.5, textColor=MUTED, alignment=TA_CENTER,
        ),
        "mono": ParagraphStyle(
            "Mono", parent=s["BodyText"], fontName="Courier", fontSize=7.3,
            leading=10, textColor=NAVY,
        ),
    }


S = styles()


def P(text: str, style: str = "body") -> Paragraph:
    return Paragraph(text, S[style])


def bullets(items: Iterable[str]):
    result = []
    for item in items:
        result.append(Paragraph(f"• {item}", S["bullet"]))
    return result


def callout(text: str, color=LIGHT_BLUE, border=BLUE):
    t = Table([[P(text, "callout")]], colWidths=[CONTENT_W])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), color),
        ("BOX", (0, 0), (-1, -1), 1, border),
        ("LEFTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 4 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
    ]))
    return t


def cover_badge(text: str, width: float):
    style = ParagraphStyle(
        "CoverBadge", parent=S["callout"], textColor=WHITE, fontSize=9.5,
        leading=13, alignment=TA_LEFT,
    )
    t = Table([[Paragraph(text, style)]], colWidths=[width])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#183F5B")),
        ("BOX", (0, 0), (-1, -1), 1, TEAL),
        ("LEFTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 4 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
    ]))
    return t


def two_column(left_title, left_items, right_title, right_items, left_color=LIGHT_TEAL, right_color=LIGHT_RED):
    left = [P(left_title, "h2")] + bullets(left_items)
    right = [P(right_title, "h2")] + bullets(right_items)
    t = Table([[left, right]], colWidths=[CONTENT_W / 2 - 2 * mm, CONTENT_W / 2 - 2 * mm], hAlign="CENTER")
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, 0), left_color),
        ("BACKGROUND", (1, 0), (1, 0), right_color),
        ("BOX", (0, 0), (0, 0), 0.8, TEAL),
        ("BOX", (1, 0), (1, 0), 0.8, RED),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 3 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3 * mm),
    ]))
    return t


def standard_table(headers, rows, widths, font_style="table", repeat=1):
    data = [[P(h, "table_head") for h in headers]]
    for row in rows:
        data.append([P(str(cell), font_style) for cell in row])
    t = Table(data, colWidths=widths, repeatRows=repeat, hAlign="LEFT")
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
        ("GRID", (0, 0), (-1, -1), 0.35, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [WHITE, PALE]),
        ("LEFTPADDING", (0, 0), (-1, -1), 2.2 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 2.2 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 1.8 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 1.8 * mm),
    ]))
    return t


class VerticalFlow(Flowable):
    def __init__(self, steps, width=CONTENT_W, box_h=10 * mm, gap=4 * mm, colors_list=None):
        super().__init__()
        self.steps = steps
        self.width = width
        self.box_h = box_h
        self.gap = gap
        self.height = len(steps) * box_h + (len(steps) - 1) * gap
        self.colors_list = colors_list or [LIGHT_BLUE] * len(steps)

    def wrap(self, availWidth, availHeight):
        return self.width, self.height

    def draw(self):
        c = self.canv
        box_w = self.width * 0.86
        x = (self.width - box_w) / 2
        y = self.height - self.box_h
        for i, step in enumerate(self.steps):
            fill = self.colors_list[i % len(self.colors_list)]
            c.setFillColor(fill)
            c.setStrokeColor(BLUE if fill != LIGHT_RED else RED)
            c.setLineWidth(0.8)
            c.roundRect(x, y, box_w, self.box_h, 3 * mm, fill=1, stroke=1)
            c.setFillColor(NAVY)
            c.setFont("Helvetica-Bold", 8.3)
            max_chars = 82
            label = step if len(step) <= max_chars else step[:max_chars - 1] + "..."
            c.drawCentredString(self.width / 2, y + self.box_h / 2 - 3, label)
            if i < len(self.steps) - 1:
                xmid = self.width / 2
                y1 = y
                y2 = y - self.gap + 1.5 * mm
                c.setStrokeColor(MUTED)
                c.line(xmid, y1, xmid, y2)
                c.setFillColor(MUTED)
                c.drawCentredString(xmid, y2 - 2.2 * mm, "v")
            y -= self.box_h + self.gap


def architecture_drawing():
    w, h = CONTENT_W, 118 * mm
    d = Drawing(w, h)

    def box(x, y, bw, bh, label, fill, stroke=BLUE, size=8.5):
        d.add(Rect(x, y, bw, bh, rx=7, ry=7, fillColor=fill, strokeColor=stroke, strokeWidth=1))
        lines = label.split("\n")
        for idx, line in enumerate(lines):
            d.add(String(x + bw / 2, y + bh / 2 + (len(lines) - 1 - 2 * idx) * 5,
                         line, fontName="Helvetica-Bold", fontSize=size,
                         fillColor=NAVY, textAnchor="middle"))

    def arrow(x1, y1, x2, y2):
        d.add(Line(x1, y1, x2, y2, strokeColor=MUTED, strokeWidth=1.4))
        if abs(x2 - x1) > abs(y2 - y1):
            direction = 1 if x2 > x1 else -1
            pts = [x2, y2, x2 - 6 * direction, y2 + 3, x2 - 6 * direction, y2 - 3]
        else:
            direction = 1 if y2 > y1 else -1
            pts = [x2, y2, x2 - 3, y2 - 6 * direction, x2 + 3, y2 - 6 * direction]
        d.add(Polygon(pts, fillColor=MUTED, strokeColor=MUTED))

    bw = 45 * mm
    bh = 19 * mm
    box(2 * mm, 86 * mm, bw, bh, "EFRM Database\nRead-only source", LIGHT_BLUE)
    box(61 * mm, 86 * mm, bw, bh, "Predefined SQL Tools\nEFRM DB Gateway", LIGHT_TEAL, TEAL)
    box(120 * mm, 86 * mm, bw, bh, "Trigger Poller / API\nFastAPI", LIGHT_AMBER, AMBER)
    arrow(47 * mm, 95 * mm, 61 * mm, 95 * mm)
    arrow(120 * mm, 95 * mm, 106 * mm, 95 * mm)

    box(61 * mm, 48 * mm, bw, 23 * mm, "Rule Optimizer Worker\nLangGraph + Python", CYAN, TEAL, 9)
    arrow(83.5 * mm, 86 * mm, 83.5 * mm, 71 * mm)

    box(2 * mm, 10 * mm, bw, bh, "Agentic PostgreSQL\nJobs, evidence, audit", LIGHT_BLUE)
    box(61 * mm, 10 * mm, bw, bh, "Artifact Storage\nSnapshot parts", LIGHT_TEAL, TEAL)
    box(120 * mm, 10 * mm, bw, bh, "LLM Gateway\nOptional explanation", LIGHT_AMBER, AMBER)
    arrow(72 * mm, 48 * mm, 30 * mm, 29 * mm)
    arrow(83.5 * mm, 48 * mm, 83.5 * mm, 29 * mm)
    arrow(95 * mm, 48 * mm, 142 * mm, 29 * mm)

    box(120 * mm, 48 * mm, bw, 23 * mm, "Recommendation API\nSSE + Human Review", LIGHT_RED, RED, 8.5)
    arrow(106 * mm, 59.5 * mm, 120 * mm, 59.5 * mm)
    return d


def db_flow_drawing():
    w, h = CONTENT_W, 125 * mm
    d = Drawing(w, h)

    def box(x, y, bw, bh, label, fill=LIGHT_BLUE, stroke=BLUE, fs=7.2):
        d.add(Rect(x, y, bw, bh, rx=4, ry=4, fillColor=fill, strokeColor=stroke, strokeWidth=0.8))
        for idx, line in enumerate(label.split("\n")):
            d.add(String(x + bw / 2, y + bh / 2 + 4 - idx * 9, line,
                         fontName="Helvetica-Bold", fontSize=fs, fillColor=NAVY,
                         textAnchor="middle"))

    def arrow(x1, y1, x2, y2):
        d.add(Line(x1, y1, x2, y2, strokeColor=MUTED, strokeWidth=1))
        d.add(Polygon([x2, y2, x2 - 4, y2 + 2.5, x2 - 4, y2 - 2.5], fillColor=MUTED, strokeColor=MUTED))

    cols = [3, 40, 77, 114, 151]
    bw, bh = 32 * mm, 12 * mm
    y1, y2, y3 = 101 * mm, 79 * mm, 57 * mm
    labels1 = ["case_master", "case_alert_mapping", "transaction/device\nalert", "transaction/device\nresult", "transaction/device\nmatch"]
    for i, label in enumerate(labels1):
        box(cols[i] * mm, y1, bw, bh, label)
        if i < 4:
            arrow((cols[i] + 32) * mm, y1 + bh / 2, cols[i + 1] * mm, y1 + bh / 2)
    box(77 * mm, y2, bw, bh, "transaction/device\nmaster", LIGHT_TEAL, TEAL)
    box(114 * mm, y2, bw, bh, "rule_master +\nrule_version", LIGHT_TEAL, TEAL)
    box(151 * mm, y2, bw, bh, "metric + policy\nconfiguration", LIGHT_TEAL, TEAL)
    arrow((114 + 16) * mm, y1, (114 + 16) * mm, y2 + bh)
    arrow((151 + 16) * mm, y1, (151 + 16) * mm, y2 + bh)
    arrow((77 + 16) * mm, y1, (77 + 16) * mm, y2 + bh)

    d.add(String(3 * mm, 47 * mm, "Agentic write path", fontName="Helvetica-Bold", fontSize=9, fillColor=TEAL))
    labels2 = ["reconciliation_cursor\n+ trigger_inbox", "agent_invocation\n+ graph_run", "case_analysis_job\n+ lineage", "rule_analysis_run\n+ snapshot", "findings -> strategy\n-> recommendation"]
    for i, label in enumerate(labels2):
        box(cols[i] * mm, y3 - 15 * mm, bw, 14 * mm, label, LIGHT_AMBER if i < 2 else LIGHT_TEAL, AMBER if i < 2 else TEAL, 6.7)
        if i < 4:
            arrow((cols[i] + 32) * mm, y3 - 8 * mm, cols[i + 1] * mm, y3 - 8 * mm)

    box(77 * mm, 7 * mm, bw, 13 * mm, "outbox_event\nrecommendation ready", LIGHT_RED, RED, 6.8)
    box(120 * mm, 7 * mm, bw, 13 * mm, "review_decision\nstatus history", LIGHT_RED, RED, 6.8)
    arrow((151 + 16) * mm, y3 - 15 * mm, (93) * mm, 20 * mm)
    arrow((77 + 32) * mm, 13.5 * mm, 120 * mm, 13.5 * mm)
    return d


class NumberedDocTemplate(BaseDocTemplate):
    def __init__(self, filename, **kwargs):
        super().__init__(filename, pagesize=A4, leftMargin=MARGIN_X, rightMargin=MARGIN_X,
                         topMargin=MARGIN_TOP, bottomMargin=MARGIN_BOTTOM, **kwargs)
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height,
                      leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
        self.addPageTemplates(PageTemplate(id="main", frames=[frame], onPageEnd=self._header_footer))

    def _header_footer(self, canvas, doc):
        page = canvas.getPageNumber()
        canvas.saveState()
        canvas.resetTransforms()
        canvas.setFont("Helvetica", 6.7)
        canvas.setFillColor(MUTED)
        canvas.drawRightString(PAGE_W - MARGIN_X, 6.5 * mm, f"Page {page}")
        canvas.restoreState()


def build_story():
    story = []

    # Cover
    cover = Table([[""]], colWidths=[PAGE_W], rowHeights=[PAGE_H - 20 * mm])
    cover.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), NAVY)]))
    title_block = [
        Spacer(1, 42 * mm),
        P("EFRM Rule Optimization Agent", "title"),
        P("Final Fixed Scope, Enterprise Architecture, LangGraph Workflow, Tools and Database Flow", "subtitle"),
        Spacer(1, 8 * mm),
        cover_badge("PHASE 1: RECOMMENDATION ONLY - NO CANDIDATE RULE, NO BACKTEST, NO PRODUCTION WRITE", CONTENT_W - 24 * mm),
        Spacer(1, 12 * mm),
        P("Purpose", "subtitle"),
        P("A boss-ready implementation reference showing exactly what the Agent does, how each workflow step operates, where SQL and the LLM are used, how recommendations are formed, and how records move through the EFRM and Agentic databases.", "subtitle"),
        Spacer(1, 20 * mm),
        P("Technology baseline: Python | FastAPI | LangGraph | PostgreSQL | Predefined SQL Tools | Optional LLM | SSE", "subtitle"),
        Spacer(1, 8 * mm),
        P("Status: Conditionally approved enterprise implementation baseline", "subtitle"),
        P("Prepared: August 2026", "subtitle"),
    ]
    inner = Table([[title_block]], colWidths=[CONTENT_W - 24 * mm], hAlign="CENTER")
    inner.setStyle(TableStyle([("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0)]))
    cover._argW = [PAGE_W]
    story.append(Table([[inner]], colWidths=[PAGE_W - 2 * MARGIN_X], rowHeights=[PAGE_H - 2 * MARGIN_TOP], style=[
        ("BACKGROUND", (0, 0), (-1, -1), NAVY),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 12 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 12 * mm),
    ]))
    story.append(PageBreak())

    # Scope
    story += [P("1. Final Fixed Scope", "h1")]
    story.append(callout("The Agent starts from finalized false-positive cases, identifies directly connected rules, analyses their relevant historical evidence, and produces an evidence-linked recommendation for human review."))
    story.append(Spacer(1, 4 * mm))
    story.append(two_column(
        "In Scope - Phase 1",
        [
            "Detect finalized false-positive cases through controlled SQL polling or an authenticated trigger API.",
            "Trace case -> alert -> result -> match -> exact rule identity/version.",
            "Analyse only rules selected from false-positive case lineage, not every production rule.",
            "Build bounded historical snapshots for each selected rule.",
            "Validate lineage, completeness, version identity, outcome mappings and data sufficiency.",
            "Calculate health, decay, threshold sensitivity, alert volume and rule overlap evidence.",
            "Create a deterministic review strategy and optional LLM explanation.",
            "Produce a structured recommendation with evidence, limitations and human-review requirement.",
            "Store complete audit, evidence, tool-execution and workflow history.",
        ],
        "Out of Scope - Phase 1",
        [
            "Generating transaction or device alerts.",
            "Scanning and optimizing all rules on a full recurring basis.",
            "Creating or compiling an executable candidate rule.",
            "Running Rule Engine replay or exact candidate backtesting.",
            "Writing, activating, deleting or retiring production rules.",
            "Claiming true risk leakage without an independent confirmed-risk population.",
            "Allowing an LLM to query the database, write SQL or calculate official metrics.",
            "Automatically learning from reviewer feedback or changing policies.",
            "Using RAG as the authoritative source for live cases, alerts, transactions or rules.",
        ],
    ))
    story += [Spacer(1, 5 * mm), P("Fixed business rule", "h2")]
    story.append(callout("A false-positive case is a trigger for investigation. It is not proof that every matched rule is defective. The rule match is binary; rule effectiveness must be established from broader historical evidence.", LIGHT_AMBER, AMBER))
    story += [Spacer(1, 4 * mm), P("Fixed technology choices", "h2")]
    tech_rows = [
        ("Workflow", "LangGraph fixed graph with conditional routing and per-rule fan-out"),
        ("Backend", "Python and FastAPI"),
        ("EFRM data access", "Predefined, parameterized, versioned, read-only SQL tools"),
        ("Agent records", "Agentic PostgreSQL"),
        ("Workflow recovery", "PostgreSQL-backed LangGraph checkpoints plus a durable worker/lease table"),
        ("Large artifacts", "SFTP or approved file storage using immutable paths, hashes and manifests"),
        ("LLM", "Optional provider-neutral gateway; local or approved external API"),
        ("UI progress", "SSE for one-way job progress; REST for final recommendation retrieval"),
    ]
    story.append(standard_table(["Area", "Decision"], tech_rows, [40 * mm, CONTENT_W - 40 * mm]))
    story.append(PageBreak())

    # Architecture
    story += [P("2. Enterprise Architecture", "h1"), architecture_drawing(), Spacer(1, 2 * mm)]
    story.append(P("Figure 1 - The Rule Optimizer is a separate read-only analytical service. It reads EFRM business data, writes only to Agentic storage, optionally calls an LLM for explanation, and returns a recommendation for human review.", "caption"))
    story += [Spacer(1, 5 * mm), P("Component responsibilities", "h2")]
    comp_rows = [
        ("Trigger Poller / API", "Finds a finalized false-positive case and creates one idempotent internal trigger."),
        ("EFRM DB Gateway", "Executes only registered SQL templates using a read-only EFRM connection."),
        ("LangGraph Orchestrator", "Controls mandatory order, branching, retries, stops and per-rule fan-out."),
        ("Python Analytics", "Calculates official counts, rates, distributions, decay and overlap."),
        ("LLM Gateway", "Explains validated findings; never establishes official facts."),
        ("Agentic PostgreSQL", "Stores jobs, state, audit, evidence, findings, strategies and recommendations."),
        ("Artifact Storage", "Stores partitioned snapshot datasets and immutable evidence artifacts."),
        ("Recommendation API", "Returns the validated recommendation and progress events to authorized users."),
    ]
    story.append(standard_table(["Component", "Single responsibility"], comp_rows, [45 * mm, CONTENT_W - 45 * mm]))
    story += [Spacer(1, 4 * mm), P("Data-access boundary", "h2")]
    story.append(callout("EFRM DB = read-only business source. Agentic DB = writable agent workflow and evidence store. No tool may write to EFRM production tables."))
    story.append(PageBreak())

    # Trigger
    story += [P("3. Before LangGraph: Trigger and Job Start", "h1")]
    trigger_steps = [
        "1. Scheduled poller reads finalized case changes using a durable high-water mark",
        "2. case.scan_finalized_after_cursor executes predefined read-only SQL",
        "3. Decision code is mapped using the institution's effective outcome mapping",
        "4. Trigger is accepted only when final normalized outcome = FALSE_POSITIVE",
        "5. Idempotency prevents the same case decision from starting twice",
        "6. trigger_inbox, configuration_snapshot, agent_invocation and graph_run are created",
        "7. Background worker claims the graph_run using a lease and invokes LangGraph",
    ]
    story.append(VerticalFlow(trigger_steps, box_h=9.5 * mm, gap=3.5 * mm,
                              colors_list=[LIGHT_BLUE, LIGHT_TEAL, LIGHT_AMBER]))
    story += [Spacer(1, 4 * mm), P("Primary Phase 1 trigger", "h2")]
    story.append(P("Because EFRM service/event integration is not confirmed, the practical Phase 1 trigger is a predefined SQL poller. It uses <b>(updated_at, case_id)</b> or another approved monotonic cursor, an overlap window, ordered pagination and idempotency. A controlled API can support manual replay. Event/outbox integration is a future improvement, not a Phase 1 dependency."))
    story += [P("Trigger input and output", "h2")]
    io_rows = [
        ("Input", "Institution ID, source system, cursor, overlap window, maximum batch size"),
        ("EFRM result", "Case ID, status, decision code, decision time, approval/finality data"),
        ("Normalized output", "FALSE_POSITIVE eligibility, case decision identity and correlation ID"),
        ("Agentic records", "reconciliation_cursor -> trigger_inbox -> agent_invocation -> graph_run"),
    ]
    story.append(standard_table(["Type", "Value"], io_rows, [36 * mm, CONTENT_W - 36 * mm]))
    story += [Spacer(1, 4 * mm), P("Required protections", "h2")]
    story += bullets([
        "Join case_alert_mapping to case_master for institution scope because case_alert_mapping does not contain institution_id.",
        "Normalize timestamp-without-time-zone fields using configured institution/source timezone.",
        "Treat case corrections and reopenings as superseding signals; do not leave an old recommendation current.",
        "Do not run the long workflow inside FastAPI request handling or BackgroundTasks; use a separate worker.",
    ])
    story.append(PageBreak())

    # Parent graph
    story += [P("4. LangGraph Parent Workflow", "h1")]
    parent_steps = [
        "Load Job and immutable policy snapshot",
        "Verify the case is still finalized as FALSE_POSITIVE",
        "Get all source-aware alerts connected to the case",
        "Trace each alert to result, transaction/device match and rule identity",
        "Select and deduplicate analysable rule/version targets",
        "Fan out one controlled rule-analysis subgraph per selected target",
        "Collect all rule results and complete the case-analysis job",
    ]
    story.append(VerticalFlow(parent_steps, box_h=10 * mm, gap=4 * mm,
                              colors_list=[LIGHT_BLUE, LIGHT_TEAL]))
    story += [Spacer(1, 4 * mm), P("LangGraph and tool distinction", "h2")]
    story.append(callout("A LangGraph node controls when work happens. A tool performs a specific retrieval or calculation. Some nodes use normal Python logic and therefore do not require an external tool."))
    parent_rows = [
        ("Load Job", "JobRepository", "Reads the job and versioned policy from Agentic PostgreSQL."),
        ("Verify Case", "case.get_final_decision", "Runs predefined SQL and confirms final normalized false-positive outcome."),
        ("Get Alerts", "case.get_alerts", "Reads case_alert_mapping and returns source-aware alert references."),
        ("Get Rule Matches", "alert.get_rule_matches", "Traverses alert -> result -> match and returns rule/version references."),
        ("Select Rules", "RuleSelectionService", "Python removes duplicates, preserves lineage and excludes unresolved targets by policy."),
        ("Fan Out", "LangGraph Send", "Starts one subgraph for each selected rule with configured concurrency limits."),
        ("Collect", "Python reducer", "Combines recommendation, no-change and insufficient-data outcomes."),
        ("Complete", "JobRepository", "Stores final job status and publishes an outbox event."),
    ]
    story.append(standard_table(["Node", "Tool/component", "What it does"], parent_rows,
                                [32 * mm, 45 * mm, CONTENT_W - 77 * mm]))
    story.append(PageBreak())

    # Rule subgraph diagram
    story += [P("5. Per-Rule LangGraph Subgraph", "h1")]
    rule_steps = [
        "Resolve historical/current configuration bundle",
        "Plan the required snapshot cohorts and fields",
        "Preflight estimated rows, size and execution mode",
        "Build bounded, frozen historical snapshot",
        "Validate lineage, data quality and sufficiency",
        "Calculate rule health metrics",
        "Detect recent-vs-baseline decay",
        "Analyse threshold sensitivity",
        "Analyse overlap and report coverage limitations",
        "Build deterministic recommendation strategy",
        "Optional LLM evidence explanation",
        "Compose, validate and save recommendation",
    ]
    story.append(VerticalFlow(rule_steps, box_h=8.2 * mm, gap=2.8 * mm,
                              colors_list=[LIGHT_BLUE, LIGHT_TEAL, LIGHT_AMBER]))
    story.append(Spacer(1, 3 * mm))
    story.append(P("The graph carries only small serializable values such as IDs, hashes, status codes, counts and artifact references. Transaction collections and DataFrames remain in snapshot artifacts or are processed through database-side aggregation/chunking.", "body"))
    story.append(PageBreak())

    # Tool catalog 1
    story += [P("6. Tool Catalogue - Retrieval and Snapshot", "h1")]
    rows1 = [
        ("case.scan_finalized_after_cursor", "Cursor + institution", "Reads only newly finalized/changed cases after the durable cursor.", "Candidate trigger rows", "EFRM SQL"),
        ("case.get_final_decision", "Institution + case ID", "Retrieves authoritative case status/decision and normalizes it through outcome mapping.", "Verified case decision", "EFRM SQL"),
        ("case.get_alerts", "Institution + case ID", "Retrieves case_alert_mapping records and source-aware alert identities.", "Alert references", "EFRM SQL"),
        ("alert.get_rule_matches", "Source + alert IDs", "Reads correct alert table, result and match rows; preserves rule code/version semantics.", "Rule-match lineage", "EFRM SQL"),
        ("rule.get_configuration_bundle", "Rule reference + effective time", "Retrieves historical/current rule, formal JSON, thresholds, metric dependencies and hashes.", "Configuration bundle", "EFRM SQL + Agentic policy"),
        ("optimizer.plan_snapshot", "Rule + policy + analyses", "Determines cohorts, fields, windows, partitions and approved query templates.", "Snapshot plan", "Python"),
        ("optimizer.preflight_snapshot", "Snapshot plan", "Runs bounded COUNT/size queries and selects aggregate, partitioned or stop mode.", "Size and execution decision", "EFRM SQL"),
        ("optimizer.build_snapshot", "Approved snapshot plan", "Coordinates aggregate queries and streamed detail extraction; freezes manifest and hashes.", "Snapshot ID + parts", "Python + EFRM SQL"),
        ("snapshot.validate", "Snapshot ID + policy", "Checks completeness, duplicates, version resolution, outcome mapping, windows and minimum data.", "Pass/warnings/block", "Python"),
    ]
    story.append(standard_table(
        ["Tool", "Input", "Exact work", "Output", "Technique"], rows1,
        [39 * mm, 30 * mm, 64 * mm, 31 * mm, 22 * mm], "tiny"
    ))
    story += [Spacer(1, 5 * mm), P("Predefined SQL tool rule", "h2")]
    story.append(callout("Every SQL tool has a fixed query ID/version, typed parameters, mandatory tenant filter, timeout, maximum result size, read-only role and execution audit. The LLM cannot create or alter SQL.", LIGHT_TEAL, TEAL))
    story.append(PageBreak())

    # Tool catalog 2
    story += [P("7. Tool Catalogue - Analytics and Recommendation", "h1")]
    rows2 = [
        ("analytics.calculate_rule_health", "Validated snapshot", "Calculates match, alert, finalized-case, associated false-positive and volume metrics.", "Health metrics + evidence", "Python/approved aggregates", "No"),
        ("analytics.detect_rule_decay", "Snapshot + baseline/recent policy", "Compares consistent periods, tests sample sufficiency and separates data/config changes.", "Decay status + evidence", "Python statistics", "No"),
        ("analytics.analyse_threshold", "Snapshot + rule threshold", "Builds value bands and estimates effect of supported threshold changes.", "Analytical threshold findings", "Python", "No"),
        ("analytics.analyse_overlap_and_coverage", "Snapshot + related matches", "Measures shared transactions/alerts/cases and states whether leakage is measurable.", "Overlap + limitations", "Python/SQL", "No"),
        ("strategy.build", "All validated findings + policy", "Selects one permitted review direction using deterministic policy rules.", "Strategy", "Python policy logic", "No"),
        ("llm.generate_explanation", "Metrics + findings + evidence IDs + strategy", "Explains observations and possible reasons in simple language; cites supplied evidence.", "Structured explanation", "LLM Gateway", "Yes"),
        ("recommendation.compose", "Strategy + findings + explanation", "Builds canonical recommendation JSON with issue, action, why, evidence and limitations.", "Draft recommendation", "Python", "No"),
        ("recommendation.validate", "Draft + evidence + current rule hash", "Checks every claim, Phase 1 boundary, required limitations and stale rule state.", "Publishable/stale/invalid", "Python + current-config SQL", "No"),
        ("recommendation.save", "Valid recommendation", "Atomically stores recommendation, evidence relationships, audit and outbox event.", "Recommendation ID", "Agentic DB repository", "No"),
    ]
    story.append(standard_table(
        ["Tool", "Input", "Exact work", "Output", "Technique", "LLM"], rows2,
        [38 * mm, 31 * mm, 58 * mm, 31 * mm, 23 * mm, 10 * mm], "tiny"
    ))
    story += [Spacer(1, 5 * mm), P("Safe metric wording", "h2")]
    story.append(callout("Use 'finalized cases associated with this rule were mapped false positive'. Do not claim precision, recall, false-negative rate or true risk leakage without an approved outcome/truth model.", LIGHT_AMBER, AMBER))
    story.append(PageBreak())

    # Snapshot
    story += [P("8. How the Historical Snapshot Works", "h1")]
    story.append(callout("The Snapshot Builder does not copy every transaction in the bank. It builds a bounded Rule Analysis Cohort for one selected rule, scope and time window."))
    cohort_rows = [
        ("Matched cohort", "Transactions/device events that historically produced a match for the selected rule/version.", "Health, threshold bands and trigger evidence"),
        ("Outcome cohort", "Alerts and finalized cases connected to those matches, including non-false-positive mapped outcomes.", "Meaningful denominator and outcome association"),
        ("Time-bucket aggregates", "Monthly/weekly counts computed inside the reporting database.", "Decay and stability without moving raw rows"),
        ("Overlap cohort", "Other rule matches sharing the same result/event population.", "Cross-rule overlap"),
        ("Near-miss cohort", "Optional bounded events close to a threshold; disabled unless policy and data access allow it.", "Limited threshold-decrease exploration"),
    ]
    story.append(standard_table(["Cohort", "Contains", "Used for"], cohort_rows,
                                [38 * mm, 86 * mm, CONTENT_W - 124 * mm]))
    story += [Spacer(1, 5 * mm), P("Scale controls", "h2")]
    story += bullets([
        "Push filtering, grouping and counting to an approved EFRM reporting replica where possible.",
        "Run a count/size preflight before detailed extraction.",
        "Stream large results in bounded chunks; never load the complete population into Python memory.",
        "Store aggregate and partition artifacts separately with hashes, row counts and source cut-off.",
        "Keep only snapshot_id, manifest hash and artifact references in LangGraph state.",
        "Stop or partition when configured row/size/time limits are exceeded; never silently shorten the analysis window.",
    ])
    story += [Spacer(1, 3 * mm), P("Snapshot output", "h2")]
    story.append(P("The output is a manifest containing the rule identity, window, source cut-off, query-template versions, included/excluded counts, artifact locations, hashes, timezone, builder version, limitations and readiness status."))
    story.append(PageBreak())

    # LLM
    story += [P("9. Exactly Where the LLM Is Used", "h1")]
    llm_flow = [
        "Deterministic SQL/Python tools calculate validated metrics and findings",
        "strategy.build selects the official review direction",
        "Prompt Builder creates a masked structured evidence package",
        "llm.generate_explanation calls the approved Model Gateway",
        "LLM returns structured explanation with evidence references",
        "Python Claim Validator rejects unsupported statements or numbers",
        "If the LLM fails, a deterministic template explanation is used",
    ]
    story.append(VerticalFlow(llm_flow, box_h=10 * mm, gap=4 * mm,
                              colors_list=[LIGHT_TEAL, LIGHT_BLUE, LIGHT_AMBER]))
    story += [Spacer(1, 4 * mm)]
    story.append(two_column(
        "LLM May Do",
        [
            "Summarize several validated findings together.",
            "Explain why review may be necessary.",
            "Describe possible evidence-supported reasons.",
            "Explain uncertainty and limitations.",
            "Write clear language for managers and fraud teams.",
        ],
        "LLM Must Never Do",
        [
            "Query EFRM or Agentic databases.",
            "Generate or execute SQL.",
            "Calculate official metrics.",
            "Invent threshold values or evidence.",
            "Select the official action or modify a rule.",
        ],
    ))
    story += [Spacer(1, 4 * mm)]
    story.append(callout("Only one LangGraph node requires LLM inference in Phase 1: Explain Evidence. Every other authoritative operation remains deterministic.", LIGHT_AMBER, AMBER))
    story.append(PageBreak())

    # Recommendation
    story += [P("10. How the Final Recommendation Is Made", "h1")]
    rec_steps = [
        "1. Analytics produce exact metrics, findings, uncertainty and evidence IDs",
        "2. Strategy Builder selects an allowed action type",
        "3. LLM or template produces readable explanation",
        "4. Python Composer creates canonical recommendation JSON",
        "5. Validator checks claims, evidence, limitations and Phase 1 restrictions",
        "6. Current rule hash is read again; changed rules become STALE",
        "7. Valid recommendation is stored and published for human review",
    ]
    story.append(VerticalFlow(rec_steps, box_h=9.5 * mm, gap=3.5 * mm,
                              colors_list=[LIGHT_TEAL, LIGHT_BLUE, LIGHT_AMBER]))
    story += [Spacer(1, 5 * mm), P("Canonical recommendation fields", "h2")]
    rec_rows = [
        ("Identity", "Recommendation ID, institution, rule, analysed version, current rule hash"),
        ("Issue", "Observed problem stated without unsupported causation"),
        ("Recommended action", "No change, threshold review, condition review, scenario review, overlap review, retirement review or insufficient evidence"),
        ("Why", "Human-readable evidence-grounded explanation"),
        ("Evidence", "Metric values, numerators/denominators, windows, finding IDs and evidence IDs"),
        ("Confidence", "Data-derived evidence strength; never an LLM-invented score"),
        ("Limitations", "Missing labels, unresolved versions, analytical-estimate status and unavailable replay"),
        ("Control", "RECOMMENDATION_ONLY and HUMAN_REVIEW_REQUIRED"),
    ]
    story.append(standard_table(["Section", "Contents"], rec_rows, [42 * mm, CONTENT_W - 42 * mm]))
    story += [Spacer(1, 4 * mm)]
    story.append(callout("Phase 1 output is advice for a governed human decision. It is not a candidate artifact and cannot be sent directly to production."))
    story.append(PageBreak())

    # DB visual
    story += [P("11. End-to-End Database Flow", "h1"), db_flow_drawing()]
    story.append(P("Figure 2 - EFRM tables are authoritative read-only sources. Agentic tables record workflow execution, evidence, recommendations and human decisions.", "caption"))
    story += [Spacer(1, 5 * mm), P("EFRM read rule", "h2")]
    story.append(P("Every predefined SQL tool goes through the EFRM DB Gateway. The gateway selects a registered query version, validates typed parameters, opens a read-only transaction, applies tenant and time bounds, executes with time/row limits, normalizes the result, and records tool execution metadata."))
    story.append(PageBreak())

    # EFRM table flow
    story += [P("12. EFRM Table-by-Table Read Flow", "h1")]
    efrm_rows = [
        ("1", "case_master", "Case header, institution, status, final decision, decision time and approval/finality information."),
        ("2", "case_alert_mapping", "Connects the case to source-aware alert_id, alert_type and alert_source_table; contains alert-level decision evidence."),
        ("3", "transaction_alert / device_alert", "Connects each source alert to its transaction_result_id or device_result_id."),
        ("4", "transaction_result / device_result", "Stores engine decision, score, matched-rule count and event/master reference."),
        ("5", "transaction_match / device_match", "Stores each fired signal with rule_code, rule_version, group version, severity and weight."),
        ("6", "transaction_master / device_master", "Provides institution, channel, transaction/device attributes, timestamp and rule-engine context."),
        ("7", "rule_master", "Provides stable logical rule identity, type and fact."),
        ("8", "rule_version", "Provides formal JSON logic, DRL, version, checksum, status and threshold-bearing conditions."),
        ("9", "rule group/binding tables", "Resolve which group/version/scope was effective for the source, channel and fact."),
        ("10", "rule_metric_dependency", "Lists metrics required by the rule."),
        ("11", "metric_definition", "Stores metric metadata and Custom SQL references; execution is disabled unless separately approved."),
        ("12", "decision policy/upgrade tables", "Explain how matched signals contributed to the engine decision."),
    ]
    story.append(standard_table(["Order", "EFRM table", "Why it is read"], efrm_rows,
                                [14 * mm, 54 * mm, CONTENT_W - 68 * mm]))
    story += [Spacer(1, 4 * mm), P("Required resolution rules", "h2")]
    story += bullets([
        "Use alert_source_table plus alert_id; never assume numeric alert IDs are globally unique.",
        "Apply institution scope through case_master and transaction/device master joins.",
        "Do not guess whether match.rule_version means rule_version.id or version_no; use an explicit source contract.",
        "When an exact deleted historical configuration cannot be found, report CONFIGURATION_AMBIGUITY or MISSING rather than inventing it.",
    ])
    story.append(PageBreak())

    # Agentic DB table flow
    story += [P("13. Agentic Database Table-by-Table Write Flow", "h1")]
    agent_rows = [
        ("1", "reconciliation_cursor", "Stores the SQL poller's durable high-water mark and overlap policy."),
        ("2", "trigger_inbox", "Stores normalized, idempotent case-finalized trigger."),
        ("3", "configuration_snapshot", "Freezes tenant capability, policy, outcome mapping and model/data settings."),
        ("4", "agent_invocation", "Represents one backend Agent run."),
        ("5", "graph_run", "Stores durable queue/lease and overall LangGraph business execution state."),
        ("6", "graph_node_execution", "Stores each node attempt, timing, retry status and input/output artifact references."),
        ("7", "case_analysis_job", "Stores one finalized-case analysis and its normalized final outcome."),
        ("8", "case_rule_lineage_item - add", "Stores every alert/result/match/rule/version path, not just one rule summary."),
        ("9", "rule_analysis_run", "Stores reusable analysis identity for rule, scope, window and configuration hash."),
        ("10", "trigger_case_link", "Links the triggering case job to selected or excluded rule-analysis targets."),
        ("11", "configuration_bundle + item - add", "Stores historical/current rule and every component/version/hash used."),
        ("12", "snapshot_manifest + dataset_part - add", "Stores bounded cohort manifests, partitions, counts, query versions and hashes."),
        ("13", "data_quality_result", "Stores every blocking/non-blocking readiness gate."),
        ("14", "rule_finding_set + finding_metric", "Stores deterministic health, decay, threshold and overlap results."),
        ("15", "strategy_set + strategy_item", "Stores deterministic review direction and supporting evidence."),
        ("16", "model_execution", "Stores model, prompt, provider, token, latency and validation metadata for optional LLM call."),
        ("17", "claim + evidence relations", "Links every important recommendation statement to evidence."),
        ("18", "recommendation", "Stores canonical JSON, readable summary, evidence strength and stale state."),
        ("19", "recommendation_status_history", "Append-only lifecycle history."),
        ("20", "outbox_event", "Reliably publishes recommendation-ready notification."),
        ("21", "review_decision", "Append-only human accept/reject/request-reanalysis record."),
        ("22", "audit_event / tool_execution", "Stores security, data access and execution audit trail."),
    ]
    story.append(standard_table(["Order", "Agentic table", "Responsibility"], agent_rows,
                                [14 * mm, 66 * mm, CONTENT_W - 80 * mm], "tiny"))
    story.append(PageBreak())

    # Enterprise controls
    story += [P("14. Enterprise Controls Required for Production", "h1")]
    control_rows = [
        ("Tenant isolation", "Institution-aware SQL filters, RLS, non-owner roles and tenant-safe foreign keys."),
        ("Database safety", "Read-only EFRM account, approved views/replica, timeouts, row limits, streaming and no dynamic SQL."),
        ("Workflow durability", "Separate worker, graph_run leases, heartbeat, idempotent nodes, retry classification and dead-letter handling."),
        ("Snapshot integrity", "Source cut-off, query versions, row counts, partition hashes, immutable artifact paths and builder version."),
        ("Data quality", "Blocking gates for missing lineage, ambiguous versions, insufficient outcomes and inconsistent mappings."),
        ("LLM safety", "Data minimization, masking, allow-listed provider, structured output, claim validation, fallback and kill switch."),
        ("Audit", "Append-only security/business events with correlation IDs from trigger to recommendation."),
        ("Observability", "Structured logs, metrics and traces; alerts for queue lag, timeouts, DQ failures and LLM validation failures."),
        ("Retention", "Institution-configurable snapshot, prompt/output, audit and recommendation retention with legal-hold support."),
        ("Governance", "No automatic rule change; every result requires human review through the existing governance process."),
    ]
    story.append(standard_table(["Control", "Required implementation"], control_rows,
                                [42 * mm, CONTENT_W - 42 * mm]))
    story += [Spacer(1, 5 * mm), P("Mandatory database corrections", "h2")]
    story += bullets([
        "Add detailed case-rule lineage, configuration component and snapshot dataset-part tables.",
        "Allow unresolved/deleted current rule configuration through an explicit resolution status.",
        "Support approved reanalysis using analysis_generation and reanalysis_of_job_id.",
        "Replace evidence ID JSON arrays with authoritative evidence-relation rows.",
        "Enforce strict CHECK constraints on job, finding, strategy and recommendation statuses.",
        "Use a separate langgraph_ckpt schema/role for LangGraph-owned checkpoint tables.",
    ])
    story.append(PageBreak())

    # Implementation plan and approval
    story += [P("15. Implementation Sequence and Approval Boundary", "h1")]
    impl_rows = [
        ("1. Foundation", "FastAPI service, settings, secrets, two DB pools, Agentic migrations, checkpoint schema and worker lease loop."),
        ("2. Trigger and lineage", "SQL poller, cursor, inbox/idempotency, case verification and source-aware case-alert-result-match-rule trace."),
        ("3. Configuration", "Explicit version semantics, historical/current bundle resolver, hashes and deleted-rule handling."),
        ("4. Snapshot", "Planner, preflight, approved query registry, aggregation, partition extraction, manifests and validation."),
        ("5. Analytics", "Health, decay, supported threshold sensitivity, overlap and evidence-strength calculation."),
        ("6. Recommendation", "Deterministic strategy, canonical composer, claim validator, stale check and database persistence."),
        ("7. Optional LLM", "Provider gateway, masking, prompt schema, structured explanation, validation and deterministic fallback."),
        ("8. UI integration", "Start/status/recommendation REST APIs, SSE progress and human-review endpoints."),
        ("9. Hardening", "Tenant tests, failure recovery, performance tests, observability, retention, backup/restore and security approval."),
    ]
    story.append(standard_table(["Build stage", "Deliverable"], impl_rows, [37 * mm, CONTENT_W - 37 * mm]))
    story += [Spacer(1, 5 * mm), P("Business and platform inputs required before production", "h2")]
    story += bullets([
        "Institution-specific outcome mapping and finality/approval rules.",
        "Exact semantics of rule_version and rule_group_version in match history.",
        "Minimum sample, health, decay and evidence-strength policies.",
        "Permitted recommendation/threshold review constraints; alert volume is currently the only capacity constraint.",
        "Approved EFRM reporting access, indexes/views and performance limits.",
        "Custom Metric SQL governance and point-in-time reproducibility policy.",
        "Historical rule retention/deletion contract.",
        "External LLM provider, data classification, egress and retention approval if external mode is enabled.",
    ])
    story += [Spacer(1, 4 * mm)]
    story.append(callout("FINAL APPROVAL POSITION: Start Phase 1 implementation as a Recommendation-Only analytical service. Do not enable production health classification, exact threshold claims, Custom SQL execution, true leakage measurement or any rule write until their required policies and data contracts are approved.", LIGHT_TEAL, TEAL))
    story += [Spacer(1, 5 * mm), P("One-sentence management explanation", "h2")]
    story.append(callout("The Agent detects finalized false-positive cases, traces them to exact rules, uses predefined read-only SQL and deterministic Python to build evidence, optionally uses an LLM to explain that evidence, and sends a validated recommendation to a human without changing any production rule.", LIGHT_BLUE, BLUE))

    return story


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = NumberedDocTemplate(
        str(OUT),
        title="EFRM Rule Optimization Agent - Final Fixed Scope and Workflow",
        author="EFRM Agentic Platform Architecture",
        subject="Recommendation-Only Rule Optimization Agent architecture",
    )
    doc.build(build_story())
    print(OUT)


if __name__ == "__main__":
    main()
