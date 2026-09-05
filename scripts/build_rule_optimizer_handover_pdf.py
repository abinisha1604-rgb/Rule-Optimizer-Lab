from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    HRFlowable,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.graphics.shapes import Drawing, Rect, String, Line, Polygon


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "pdf" / "EFRM_Rule_Optimization_Agent_Project_Handover_and_First_PR_MVP.pdf"
OUT.parent.mkdir(parents=True, exist_ok=True)

NAVY = colors.HexColor("#0B2545")
BLUE = colors.HexColor("#1F5E86")
TEAL = colors.HexColor("#167A83")
INK = colors.HexColor("#1F2937")
MUTED = colors.HexColor("#5B677A")
LIGHT = colors.HexColor("#F4F7FA")
LIGHT_BLUE = colors.HexColor("#EAF2F7")
PALE_TEAL = colors.HexColor("#E8F4F3")
GOLD = colors.HexColor("#A66A00")
GRID = colors.HexColor("#CBD5E1")
WHITE = colors.white
RED = colors.HexColor("#A33A3A")


def register_fonts():
    font_dir = Path(r"C:\Windows\Fonts")
    regular = font_dir / "arial.ttf"
    bold = font_dir / "arialbd.ttf"
    mono = font_dir / "consola.ttf"
    if regular.exists() and bold.exists():
        pdfmetrics.registerFont(TTFont("DocSans", str(regular)))
        pdfmetrics.registerFont(TTFont("DocSans-Bold", str(bold)))
    if mono.exists():
        pdfmetrics.registerFont(TTFont("DocMono", str(mono)))


register_fonts()
SANS = "DocSans" if "DocSans" in pdfmetrics.getRegisteredFontNames() else "Helvetica"
SANS_B = "DocSans-Bold" if "DocSans-Bold" in pdfmetrics.getRegisteredFontNames() else "Helvetica-Bold"
MONO = "DocMono" if "DocMono" in pdfmetrics.getRegisteredFontNames() else "Courier"


class HandoverDoc(BaseDocTemplate):
    def __init__(self, filename):
        super().__init__(
            filename,
            pagesize=A4,
            leftMargin=18 * mm,
            rightMargin=18 * mm,
            topMargin=19 * mm,
            bottomMargin=18 * mm,
            title="EFRM Rule Optimization Agent - Project Handover and First PR MVP",
            author="EFRM Agentic Platform Team",
            subject="Architecture, decisions, first PR scope, database and implementation handover",
        )
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            id="normal",
        )
        self.addPageTemplates(PageTemplate(id="main", frames=[frame], onPage=self._header_footer))

    def _header_footer(self, canv: canvas.Canvas, doc):
        canv.saveState()
        if doc.page > 1:
            canv.setFont(SANS_B, 7.5)
            canv.setFillColor(MUTED)
            canv.drawString(18 * mm, A4[1] - 11 * mm, "EFRM AI AGENTIC PLATFORM | RULE OPTIMIZER HANDOVER")
            canv.setStrokeColor(GRID)
            canv.setLineWidth(0.4)
            canv.line(18 * mm, A4[1] - 13 * mm, A4[0] - 18 * mm, A4[1] - 13 * mm)
            canv.setFont(SANS, 7.5)
            canv.drawRightString(A4[0] - 18 * mm, 9 * mm, f"Internal working document | Page {doc.page}")
        canv.restoreState()


styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="DocTitle", fontName=SANS_B, fontSize=26, leading=31, textColor=NAVY,
    spaceAfter=8, alignment=TA_LEFT,
))
styles.add(ParagraphStyle(
    name="DocSubtitle", fontName=SANS, fontSize=13, leading=18, textColor=MUTED,
    spaceAfter=18,
))
styles.add(ParagraphStyle(
    name="H1x", fontName=SANS_B, fontSize=16, leading=20, textColor=BLUE,
    spaceBefore=13, spaceAfter=7, keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="H2x", fontName=SANS_B, fontSize=12.2, leading=15, textColor=NAVY,
    spaceBefore=10, spaceAfter=5, keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="H3x", fontName=SANS_B, fontSize=10.4, leading=13, textColor=TEAL,
    spaceBefore=7, spaceAfter=3, keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="Bodyx", fontName=SANS, fontSize=9.2, leading=13.2, textColor=INK,
    spaceAfter=5,
))
styles.add(ParagraphStyle(
    name="Smallx", fontName=SANS, fontSize=7.6, leading=10.2, textColor=INK,
    spaceAfter=3,
))
styles.add(ParagraphStyle(
    name="Bulletx", fontName=SANS, fontSize=8.9, leading=12.5, textColor=INK,
    leftIndent=12, firstLineIndent=-7, bulletIndent=3, spaceAfter=3,
))
styles.add(ParagraphStyle(
    name="Numberx", fontName=SANS, fontSize=8.9, leading=12.5, textColor=INK,
    leftIndent=16, firstLineIndent=-12, spaceAfter=4,
))
styles.add(ParagraphStyle(
    name="Calloutx", fontName=SANS, fontSize=9.2, leading=13, textColor=INK,
    spaceAfter=0,
))
styles.add(ParagraphStyle(
    name="Codex", fontName=MONO, fontSize=7.6, leading=10.2, textColor=NAVY,
    leftIndent=5, rightIndent=5, spaceBefore=3, spaceAfter=7,
))
styles.add(ParagraphStyle(
    name="Captionx", fontName=SANS, fontSize=7.4, leading=9.5, textColor=MUTED,
    alignment=TA_CENTER, spaceBefore=3, spaceAfter=7,
))


def P(text, style="Bodyx"):
    return Paragraph(text, styles[style])


def h1(text): return P(text, "H1x")
def h2(text): return P(text, "H2x")
def h3(text): return P(text, "H3x")


def bullet(text):
    return Paragraph(f"- {text}", styles["Bulletx"])


def numbered(n, text):
    return Paragraph(f"{n}. {text}", styles["Numberx"])


def code(text):
    return Preformatted(text, styles["Codex"])


def callout(label, text, fill=LIGHT_BLUE, edge=BLUE):
    t = Table([[P(f"<b>{label}</b>  {text}", "Calloutx")]], colWidths=[174 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), fill),
        ("BOX", (0, 0), (-1, -1), 1, edge),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return KeepTogether([t, Spacer(1, 5)])


def table(headers, rows, widths=None, font=7.3, repeat=1):
    pdata = [[P(f"<b>{x}</b>", "Smallx") for x in headers]]
    for row in rows:
        pdata.append([P(str(x), "Smallx") for x in row])
    if widths is None:
        widths = [174 * mm / len(headers)] * len(headers)
    t = Table(pdata, colWidths=widths, repeatRows=repeat, hAlign="LEFT")
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
        ("GRID", (0, 0), (-1, -1), 0.35, GRID),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    for i in range(1, len(pdata)):
        if i % 2 == 0:
            style.append(("BACKGROUND", (0, i), (-1, i), LIGHT))
    t.setStyle(TableStyle(style))
    return [t, Spacer(1, 6)]


def arrow(d, x1, y1, x2, y2, color=TEAL):
    d.add(Line(x1, y1, x2, y2, strokeColor=color, strokeWidth=1.6))
    if abs(x2 - x1) >= abs(y2 - y1):
        if x2 >= x1:
            pts = [x2, y2, x2 - 7, y2 + 3.5, x2 - 7, y2 - 3.5]
        else:
            pts = [x2, y2, x2 + 7, y2 + 3.5, x2 + 7, y2 - 3.5]
    else:
        if y2 >= y1:
            pts = [x2, y2, x2 - 3.5, y2 - 7, x2 + 3.5, y2 - 7]
        else:
            pts = [x2, y2, x2 - 3.5, y2 + 7, x2 + 3.5, y2 + 7]
    d.add(Polygon(pts, fillColor=color, strokeColor=color))


def box(d, x, y, w, h, lines, fill=LIGHT_BLUE, stroke=BLUE, size=7.5):
    d.add(Rect(x, y, w, h, rx=7, ry=7, fillColor=fill, strokeColor=stroke, strokeWidth=1))
    text_lines = lines if isinstance(lines, list) else [lines]
    total = len(text_lines) * (size + 3)
    yy = y + h / 2 + total / 2 - size
    for line in text_lines:
        d.add(String(x + w / 2, yy, line, fontName=SANS_B if line == text_lines[0] else SANS,
                     fontSize=size, fillColor=NAVY, textAnchor="middle"))
        yy -= size + 3


def future_architecture_diagram():
    d = Drawing(492, 245)
    box(d, 8, 165, 100, 48, ["Existing EFRM", "read-only database"], PALE_TEAL, TEAL)
    box(d, 140, 165, 100, 48, ["Predefined SQL", "Python tools"])
    box(d, 272, 165, 100, 48, ["Trigger", "poller/event/API"])
    box(d, 172, 85, 145, 55, ["Agentic Service", "FastAPI + worker", "LangGraph"])
    box(d, 8, 8, 105, 45, ["Agentic PostgreSQL", "jobs and evidence"], LIGHT, TEAL)
    box(d, 135, 8, 105, 45, ["langgraph_ckpt", "workflow state"], LIGHT, TEAL)
    box(d, 262, 8, 105, 45, ["Object storage", "Parquet snapshots"], LIGHT, TEAL)
    box(d, 389, 8, 95, 45, ["Human review", "governance"], PALE_TEAL, TEAL)
    box(d, 392, 165, 92, 48, ["Optional LLM", "explanation only"], colors.HexColor("#FFF4D6"), GOLD)
    arrow(d, 108, 189, 140, 189)
    arrow(d, 240, 189, 272, 189)
    arrow(d, 322, 165, 290, 140)
    arrow(d, 392, 189, 317, 120, GOLD)
    arrow(d, 205, 85, 60, 53)
    arrow(d, 235, 85, 188, 53)
    arrow(d, 270, 85, 315, 53)
    arrow(d, 317, 112, 436, 53)
    return d


def mvp_sequence_diagram():
    d = Drawing(492, 282)
    xs = [35, 130, 230, 340, 438]
    labels = ["Client", "FastAPI", "Worker", "Planner", "LangGraph"]
    for x, label in zip(xs, labels):
        box(d, x - 34, 245, 68, 27, [label], LIGHT_BLUE, BLUE, 7)
        d.add(Line(x, 240, x, 15, strokeColor=GRID, strokeWidth=0.8))
    events = [
        (35, 130, 225, "POST invocation"),
        (130, 230, 195, "queued invocation"),
        (230, 340, 164, "LLM plan if enabled"),
        (340, 230, 137, "plan or failure"),
        (230, 438, 106, "invoke with plan"),
        (438, 230, 75, "final state"),
        (230, 130, 44, "save final status"),
    ]
    for x1, x2, y, label in events:
        arrow(d, x1, y, x2, y, TEAL if x2 >= x1 else BLUE)
        d.add(String((x1 + x2) / 2, y + 5, label, fontName=SANS, fontSize=6.6,
                     fillColor=INK, textAnchor="middle"))
    return d


def langgraph_loop_diagram():
    d = Drawing(492, 225)
    box(d, 15, 165, 83, 38, ["START", "initial state"], PALE_TEAL, TEAL)
    box(d, 126, 165, 88, 38, ["load_plan", "check plan"])
    box(d, 242, 165, 105, 38, ["execute_step", "call handler"])
    box(d, 375, 165, 102, 38, ["route", "next decision"])
    box(d, 110, 70, 105, 38, ["fail", "failure result"], colors.HexColor("#FCEAEA"), RED)
    box(d, 295, 70, 105, 38, ["finalize", "final result"], PALE_TEAL, TEAL)
    arrow(d, 98, 184, 126, 184)
    arrow(d, 214, 184, 242, 184)
    arrow(d, 347, 184, 375, 184)
    arrow(d, 426, 165, 426, 132)
    d.add(Line(426, 132, 294, 132, strokeColor=TEAL, strokeWidth=1.6))
    d.add(Line(294, 132, 294, 165, strokeColor=TEAL, strokeWidth=1.6))
    d.add(Polygon([294, 165, 290.5, 158, 297.5, 158], fillColor=TEAL, strokeColor=TEAL))
    d.add(String(360, 136, "more steps", fontName=SANS, fontSize=6.7, fillColor=INK, textAnchor="middle"))
    arrow(d, 406, 165, 348, 108, TEAL)
    d.add(String(380, 126, "finished", fontName=SANS, fontSize=6.7, fillColor=INK, textAnchor="middle"))
    arrow(d, 390, 165, 210, 108, RED)
    d.add(String(278, 126, "error", fontName=SANS, fontSize=6.7, fillColor=RED, textAnchor="middle"))
    arrow(d, 162, 70, 162, 35, BLUE)
    arrow(d, 347, 70, 347, 35, BLUE)
    d.add(String(162, 23, "END", fontName=SANS_B, fontSize=8, fillColor=NAVY, textAnchor="middle"))
    d.add(String(347, 23, "END", fontName=SANS_B, fontSize=8, fillColor=NAVY, textAnchor="middle"))
    return d


def mvp_db_diagram():
    d = Drawing(492, 255)
    box(d, 18, 180, 110, 42, ["agent_invocation", "request + status"], PALE_TEAL, TEAL)
    box(d, 190, 180, 110, 42, ["execution_plan", "LLM/fixed plan"])
    box(d, 362, 180, 110, 42, ["model_execution", "LLM metadata"])
    box(d, 105, 95, 110, 42, ["graph_run", "overall graph run"])
    box(d, 278, 95, 125, 42, ["graph_node_execution", "node attempts"])
    box(d, 190, 12, 120, 42, ["langgraph_ckpt", "4 managed tables"], LIGHT, TEAL)
    arrow(d, 128, 201, 190, 201)
    arrow(d, 300, 201, 362, 201)
    arrow(d, 73, 180, 150, 137)
    arrow(d, 215, 116, 278, 116)
    arrow(d, 340, 95, 250, 54)
    return d


story = []

# Cover
story += [
    Spacer(1, 18 * mm),
    P("PROJECT HANDOVER", "Smallx"),
    P("EFRM Rule Optimization Agent", "DocTitle"),
    P("Complete project context, architecture decisions, current status, first-PR MVP and continuation plan", "DocSubtitle"),
    HRFlowable(width="100%", thickness=2, color=TEAL, spaceAfter=12),
]
story += table(
    ["Document field", "Value"],
    [
        ["Purpose", "Enable another team member to understand the project and continue implementation without additional explanation."],
        ["Current implementation priority", "First-PR MVP: API trigger, optional LLM Planner, fixed-plan fallback, one background worker and LangGraph Plan-and-Execute flow."],
        ["Long-term product scope", "Enterprise Rule Optimization Agent for evidence-based recommendations on transaction-monitoring rules."],
        ["Authority", "Recommendation only. No production rule write, retirement or deletion."],
        ["Technology baseline", "Python, FastAPI, LangGraph and PostgreSQL. No Temporal, Java or Spring Boot for Phase 1."],
        ["Status date", "31 August 2026"],
    ],
    [42 * mm, 132 * mm],
)
story += [
    callout("One-sentence summary", "The project will build a separate Agentic Platform service that eventually analyzes rules linked to finalized false-positive cases, but the immediate first PR only proves the reusable API, LLM planning, background execution, LangGraph state flow and minimum persistence."),
    Spacer(1, 18 * mm),
    P("Internal working document", "Smallx"),
    P("This document records agreed decisions and explicitly separates completed design work from unimplemented functionality.", "Smallx"),
    PageBreak(),
]

# TOC
story += [h1("Contents")]
contents = [
    "Executive handover summary",
    "Product problem and intended outcome",
    "Final product scope and authority",
    "Enterprise target architecture",
    "Complete future Rule Optimizer workflow",
    "Data, snapshot and analytics design",
    "LLM, RAG and deterministic processing boundaries",
    "Shared Agentic Platform and database design",
    "Current project status and decisions already completed",
    "Immediate first-PR MVP scope",
    "First-PR execution story",
    "LangGraph Plan-and-Execute behavior",
    "Minimum first-PR database model",
    "First-PR APIs, worker and configuration",
    "First-PR acceptance criteria and test plan",
    "Implementation sequence and repository structure",
    "Deferred work and subsequent PR roadmap",
    "Open inputs and risks",
    "Decision log",
    "Handover checklist and glossary",
]
for i, item in enumerate(contents, 1):
    story.append(numbered(i, item))
story += [PageBreak()]

# 1
story += [h1("1. Executive handover summary")]
story += [
    P("The Rule Optimization Agent belongs to a separate shared Agentic Platform, not to the existing EFRM Rule Engine. The platform will host multiple agents, beginning with the Rule Optimizer and Executive Copilot. The Rule Optimizer is a background analytical agent; it does not create transaction alerts and it does not directly change production rules."),
    P("The long-term Rule Optimizer starts from finalized false-positive cases. It traces each case to its alerts, match records and exact historical rule versions, builds a bounded historical snapshot, runs deterministic analytics, optionally uses an LLM to explain validated findings, and produces a recommendation for human review."),
    P("The immediate implementation priority is narrower. The first PR is an MVP of the generic Plan-and-Execute runtime. It must receive an API request, create or load an execution plan, invoke LangGraph through one background worker, execute demonstration steps, persist status and checkpoint state, and return a final result. It must not yet access EFRM data or implement Rule Optimization tools."),
]
story += [callout("Critical separation", "Enterprise architecture describes where the product is going. First-PR MVP scope describes what must be coded now. Team members must not implement future analytics or EFRM integration inside the first PR.", PALE_TEAL, TEAL)]

story += [h2("1.1 Current status at handover")]
story += table(
    ["Area", "Status", "Meaning"],
    [
        ["Product documents", "Reviewed", "PRD, database flow reference, platform diagram, colleague review and updated Agentic DB design were analyzed."],
        ["Enterprise architecture", "Designed", "Components, data boundaries, workflow, tool families, LLM boundary and database flow are documented."],
        ["Phase 1 authority", "Finalized", "Recommendation only; humans and existing governance own production changes."],
        ["First-PR MVP", "Finalized for implementation", "API, optional LLM Planner, fixed plan, one worker, LangGraph and five application tables."],
        ["Production code", "Not confirmed as implemented", "This handover does not claim that the runtime or Rule Optimizer has been coded."],
        ["EFRM integration", "Deferred", "No Case/Alert/Rule service contract or production read connection is confirmed."],
    ],
    [35 * mm, 34 * mm, 105 * mm],
)

# 2
story += [h1("2. Product problem and intended outcome")]
story += [
    P("The existing EFRM platform already contains transaction-monitoring rules, processes transaction or device facts, generates alerts and supports cases and investigations. Rules behave as binary match/no-match controls. A rule can be technically correct but still contribute to a case that is finally closed as a false positive."),
    P("The business requirement changed from continuously analyzing every rule to prioritizing only the rules connected to finalized false-positive cases. This creates a focused and explainable starting signal."),
]
story += [h2("2.1 Business question")]
for x in [
    "Which exact rules and historical rule versions contributed to a finalized false-positive case?",
    "Is the rule generating useful alerts or excessive unnecessary alerts?",
    "Has the rule's effectiveness or stability changed over time?",
    "Could its threshold or scenario logic be reviewed to reduce unnecessary alerts without unsupported risk claims?",
    "What evidence should a human reviewer see before deciding whether to change the rule?",
]: story.append(bullet(x))
story += [h2("2.2 Intended long-term output")]
story += [
    P("The primary output is a human-review recommendation, not an automatically applied rule change."),
]
story += table(
    ["Output field", "Meaning"],
    [
        ["Rule reference", "Exact logical rule and analyzed historical version."],
        ["Issue", "Observed problem such as false-positive concentration, decay, unstable behavior or overlap."],
        ["Recommended action", "Review threshold, review condition, investigate overlap, collect evidence, no change or consider retirement."],
        ["Reason", "Clear explanation of why the action is suggested."],
        ["Evidence", "Metrics, periods, denominators, lineage references, hashes and limitations."],
        ["Expected impact", "Directional expectation such as lower alert volume; not an unsupported production guarantee."],
        ["Authority", "HUMAN_REVIEW_REQUIRED."],
    ],
    [42 * mm, 132 * mm],
)

# 3
story += [h1("3. Final product scope and authority")]
story += [h2("3.1 Long-term capabilities")]
for x in [
    "Rule health analysis: volume, outcome quality, contribution, stability, capacity and evidence strength.",
    "Rule decay detection: configurable comparison of baseline and recent periods with minimum sample and persistence gates.",
    "Threshold analysis: sensitivity around existing thresholds and alert-volume constraints.",
    "Scenario recommendation: evidence-bounded suggestions to review conditions, grouping or overlap.",
    "Historical backtesting: future Candidate + Test mode, subject to rule compiler and simulator integration.",
    "Risk leakage reporting: only evidence-supported internal gaps; do not claim true fraud recall without an independent truth source.",
    "Human-review recommendation with evidence, limitations and immutable history.",
]: story.append(bullet(x))
story += [h2("3.2 Phase 1 - Recommendation Only")]
story += [
    P("Phase 1 analyzes existing rule evidence and produces a recommendation. It does not create an executable candidate in the Rule Engine, compile DRL, write rule configuration or deploy a rule."),
]
story += [callout("Production boundary", "The agent cannot create, modify, retire or delete production rules. Any actual change must be performed by authorized humans through existing EFRM governance.", colors.HexColor("#FFF4D6"), GOLD)]
story += [h2("3.3 Future configurable mode")]
story += table(
    ["Mode", "Behavior", "Status"],
    [
        ["Recommendation Only", "Analyze evidence and produce human-readable advice. No candidate execution is required.", "Phase 1"],
        ["Candidate + Test", "Create a candidate representation, verify the simulator with the current rule, backtest the candidate and compare results.", "Deferred"],
    ],
    [38 * mm, 100 * mm, 36 * mm],
)
story += [h2("3.4 Institution and channel neutrality")]
story += [
    P("The agent is not designed for one institution, transaction type, channel or device type. Institution-specific outcome mappings, time windows, thresholds, metric policies, constraints and permissions must eventually be configuration, not hard-coded logic."),
    P("The supplied data is test/sample data. Its row counts and distributions must not be used for production sizing or performance assumptions."),
]

# 4
story += [PageBreak(), h1("4. Enterprise target architecture")]
story += [future_architecture_diagram(), P("Figure 1. Long-term architecture and ownership boundaries", "Captionx")]
story += [h2("4.1 Component responsibilities")]
story += table(
    ["Component", "Responsibility"],
    [
        ["Existing EFRM", "Authoritative source for cases, alerts, decisions, transactions, devices, matches, rules and permissions."],
        ["Read-only data tools", "Predefined parameterized SQL handlers for current Phase 1 data access. No model-generated SQL."],
        ["FastAPI", "Trigger, status, recommendation and future review endpoints."],
        ["Background worker", "Claims queued work, prepares the plan, creates the graph run, calls LangGraph and saves final status."],
        ["LangGraph", "Controls state, node order, conditional routing, checkpoints and recovery."],
        ["Python analytics", "Produces official deterministic metrics and findings."],
        ["LLM gateway", "Planner in generic platform flows and explanation in the future optimizer; no unrestricted database access."],
        ["Agentic PostgreSQL", "Application configuration, executions, artifacts, findings, recommendations and audit."],
        ["Object storage", "Large partitioned Parquet snapshots and large artifacts."],
        ["Human review", "Reviews recommendations and uses existing governance for any production change."],
    ],
    [42 * mm, 132 * mm],
)
story += [h2("4.2 Technology decisions")]
story += table(
    ["Decision", "Chosen direction", "Reason"],
    [
        ["Language", "Python", "LangGraph, analytics and agent tooling are implemented in one stack."],
        ["API", "FastAPI", "Async internal API and clear schema contracts."],
        ["Workflow", "LangGraph", "Shared state, conditional routing and PostgreSQL checkpoints."],
        ["Application database", "PostgreSQL", "Relational execution, evidence, recommendation and audit records."],
        ["Vector retrieval", "pgvector later; Qdrant/Pinecone possible later", "RAG is supportive, not required for core Rule Optimizer truth."],
        ["Files", "Approved object/analytical store; SFTP only for transport", "Large snapshots should not be stored in checkpoints or operational tables."],
        ["Excluded", "No Temporal, Java or Spring Boot for Phase 1", "The selected shared platform is Python and LangGraph."],
    ],
    [34 * mm, 54 * mm, 86 * mm],
)

# 5
story += [h1("5. Complete future Rule Optimizer workflow")]
future_steps = [
    ("Trigger", "Detect a newly finalized false-positive case through polling, a future event or an authorized API."),
    ("Verify case", "Re-read the authoritative final case decision. The final case decision takes precedence over alert-level decisions."),
    ("Get alerts", "Resolve all source-aware alerts connected to the case."),
    ("Get rule matches", "Follow alert to result/fact/match records and capture exact rule and version identity."),
    ("Select rules", "Deduplicate matches while preserving multiple historical versions of the same logical rule."),
    ("Resolve configuration", "Retrieve historical and current rule configuration, groups, thresholds and Metric Definition Custom SQL references."),
    ("Plan snapshot", "Select bounded institution/rule/fact scope, cutoff, windows, cohorts, fields and partitions."),
    ("Build snapshot", "Execute approved SQL, aggregate or page large data, and write large results to partitioned Parquet."),
    ("Validate data", "Check lineage, version resolution, completeness, sample sufficiency, freshness and reproducibility."),
    ("Run analytics", "Calculate health, decay, threshold behavior, overlap and evidence-supported gaps using Python and SQL."),
    ("Build strategy", "Apply deterministic institution policy to choose allowed recommendation directions."),
    ("Explain", "Optionally ask an LLM to explain only validated findings and limitations."),
    ("Compose and validate", "Create canonical recommendation JSON and reject unsupported claims or stale evidence."),
    ("Save and review", "Persist recommendation, evidence and status for human review. Governance owns production changes."),
]
for i, (name, desc) in enumerate(future_steps, 1):
    story.append(numbered(i, f"<b>{name}:</b> {desc}"))
story += [h2("5.1 Trigger decision")]
story += table(
    ["Option", "Use"],
    [
        ["Scheduled SQL poller", "Current practical Phase 1 option because service/event contracts are not confirmed."],
        ["Event", "Preferred future integration if EFRM publishes a durable CASE_FINALIZED event."],
        ["API", "Authorized manual reanalysis or normalized internal trigger."],
    ],
    [44 * mm, 130 * mm],
)
story += [h2("5.2 Data access decision")]
story += [
    P("For current Phase 1 design, the optimizer does not assume direct connectivity to Case Service, Alert Service or Rule Service. It uses predefined, parameterized SQL tools against an approved EFRM read-only boundary. Later APIs may implement the same tool contracts without changing the LangGraph workflow."),
    callout("LLM restriction", "The LLM does not generate SQL, execute SQL, calculate official metrics or receive unrestricted EFRM database access."),
]

# 6
story += [h1("6. Data, snapshot and analytics design")]
story += [h2("6.1 Meaning of eligible transactions or facts")]
story += [
    P("The snapshot builder does not copy every EFRM transaction for every rule run. It creates a bounded population defined by institution, selected rule/version, fact type, source-aware lineage, configured windows and analysis policy."),
]
story += table(
    ["Population", "Purpose", "Control"],
    [
        ["Rule-evaluated or matched population", "Understand volume and outcome behavior for the selected rule.", "Point-in-time rule/version context."],
        ["False-positive-linked population", "Measure the triggering outcome signal.", "Final outcome mapping and maturity policy."],
        ["Comparable non-match population", "Support comparisons only where technically available.", "Explicit cohort definition; never invent negatives."],
        ["Near-threshold band", "Study threshold sensitivity.", "Configured band and minimum sample."],
        ["Overlap population", "Find rules that fired together.", "Source-aware match lineage."],
    ],
    [48 * mm, 70 * mm, 56 * mm],
)
story += [h2("6.2 Storage rule")]
for x in [
    "Small metadata, counts, hashes, findings and recommendations belong in Agentic PostgreSQL.",
    "Large snapshot rows belong in partitioned Parquet in approved object or analytical storage.",
    "LangGraph checkpoints store workflow state and references, never the complete analytical snapshot.",
    "The snapshot manifest stores cutoff, window, schema, query hash, row counts, parts, watermarks and reconstruction information.",
]: story.append(bullet(x))
story += [h2("6.3 Metric families")]
story += table(
    ["Family", "Examples", "Important limitation"],
    [
        ["Volume", "Match count, alert count, case count and alert rate.", "Always include denominator and period."],
        ["Outcome quality", "False-positive rate, yield and conversion after finalized outcomes.", "Do not treat unresolved cases as negatives."],
        ["Contribution", "Share of alerts/cases where the selected rule contributed.", "Deduplicate with match-level lineage."],
        ["Stability", "Variance, confidence intervals and segment drift.", "Require minimum sample and persistence."],
        ["Decay", "Baseline versus recent deltas and sustained deterioration.", "One unusual day is not decay."],
        ["Threshold", "Outcome and volume sensitivity around current values.", "Alert-volume limit is the current confirmed capacity constraint."],
        ["Overlap/leakage", "Duplicate signals and evidence-supported internal gaps.", "Do not claim true recall without independent labels."],
    ],
    [34 * mm, 76 * mm, 64 * mm],
)

# 7
story += [h1("7. LLM, RAG and deterministic processing boundaries")]
story += [h2("7.1 Two different LLM roles")]
story += table(
    ["Location", "When used", "What it may do", "What it may not do"],
    [
        ["Generic Planner", "Optional at workflow level; always LLM-based if invoked.", "Create a structured plan using allowed stage names.", "Invent code, permissions or unauthorized tools."],
        ["Optimizer explanation", "Future full workflow after validated analytics.", "Explain findings, evidence and limitations in readable language.", "Access EFRM directly, calculate metrics or approve strategy."],
    ],
    [31 * mm, 44 * mm, 48 * mm, 51 * mm],
)
story += [h2("7.2 Planner decision")]
story += [
    P("The Planner component is LLM-only. Invoking it is optional at the workflow level. The current Rule Optimizer may bypass it and use an approved fixed plan. If the Planner is invoked and fails, the execution continues with the approved fixed fallback plan."),
]
story += [code(
"Workflow configuration\n"
"  planner enabled  -> LLM Planner -> validate -> LangGraph\n"
"  planner bypassed -> approved fixed plan -> LangGraph\n"
"  planner failed   -> record failure -> fixed fallback -> LangGraph"
)]
story += [h2("7.3 RAG decision")]
story += [
    P("RAG may later provide policy documents, rule-engine documentation, operating procedures and explanations of configuration fields. It is not the source of truth for cases, transactions, matches, outcomes or rule versions. Those remain database/service records."),
]

# 8
story += [h1("8. Shared Agentic Platform and database design")]
story += [h2("8.1 Physical design")]
story += table(
    ["Area", "Design"],
    [
        ["Database", "One PostgreSQL database named efrm_agentic."],
        ["Application schema", "agentic - application-owned configuration, execution, evidence and optimizer records."],
        ["Checkpoint schema", "langgraph_ckpt - runtime-owned checkpoint tables."],
        ["EFRM truth", "External existing EFRM database/read boundary; read-only to the agent."],
        ["Large data", "Object/analytical store for Parquet snapshots; SFTP only for approved transport."],
    ],
    [45 * mm, 129 * mm],
)
story += [h2("8.2 Updated database design status")]
story += [
    P("The reviewed Agentic DB v1.1 contains 91 application tables and four LangGraph checkpoint tables. It is a shared enterprise target schema, not the minimum schema required for the first PR."),
]
story += [h2("8.3 Important database corrections already identified")]
for x in [
    "Make case-rule lineage source-aware and generic enough for transaction, device and future fact types.",
    "Allow the same logical rule to appear with multiple historical versions in one case.",
    "Allow a missing current-rule hash when a current rule was deleted or cannot be resolved.",
    "Represent Phase 1 strategy as deterministic; keep LLM metadata for explanation, not strategy ownership.",
    "Add STRATEGY_ITEM to controlled evidence subject types.",
    "Seed all required tools, stages, policies and bindings before a full workflow can run.",
]: story.append(bullet(x))
story += [h2("8.4 Important source-system facts")]
for x in [
    "Decision codes vary by institution and may change; outcome meaning must be mapped by configuration.",
    "The final case decision takes precedence when alert and case decisions conflict.",
    "Aggregated_metric is not currently used. Derived metrics are represented through Metric Definition Custom SQL.",
    "Metric Definition Custom SQL does not yet have confirmed governance controls.",
    "The existing formal rule representation and JSON-to-DRL compiler exist, but their integration contract is unconfirmed.",
    "Historical match rows may reference deleted rules; the agent must record missing history and never guess a version.",
]: story.append(bullet(x))

# 9
story += [h1("9. Current project status and decisions already completed")]
story += table(
    ["Completed design work", "Result"],
    [
        ["Product and database review", "Existing product flows, schema groups, Rule Engine concepts and shared Agentic DB were reviewed from available documents and sample schema."],
        ["Architecture refinement", "Separate repository/service, Python/FastAPI/LangGraph stack, read-only EFRM boundary and human-governed authority were finalized."],
        ["Workflow design", "Trigger-to-recommendation nodes, tool responsibilities, input/output boundaries and LLM location were defined."],
        ["Snapshot guidance", "Bounded extraction, Parquet storage, manifests and data-quality controls were defined."],
        ["Database alignment", "Agentic DB v1.1 table flow and required corrections were documented."],
        ["First-PR decision", "The manager requested Plan-and-Execute architecture before actual optimizer tools; MVP scope was reduced accordingly."],
    ],
    [52 * mm, 122 * mm],
)
story += [h2("9.1 What has not been completed")]
for x in [
    "No production Rule Optimizer code implementation is confirmed by this handover.",
    "No EFRM read-only connection, safe views or production service contracts are confirmed.",
    "No production-scale historical dataset or sizing evidence is available.",
    "No final metric thresholds, decay windows, sample-size policy or outcome mapping set is approved.",
    "No LLM deployment/provider and no production data-egress decision is confirmed.",
    "No candidate compilation or simulator integration is confirmed.",
]: story.append(bullet(x))

# 10
story += [h1("10. Immediate first-PR MVP scope")]
story += [callout("First PR objective", "Prove that the platform can receive an invocation, create or load a plan, execute the plan through LangGraph using one background worker, persist status and recover graph state. No Rule Optimization business step is included.", PALE_TEAL, TEAL)]
story += [h2("10.1 Build in this PR")]
for x in [
    "FastAPI trigger endpoint.",
    "FastAPI status endpoint.",
    "One separately running Python background worker.",
    "Optional LLM Planner component; it always uses an LLM when invoked.",
    "Approved fixed plan and fixed-plan fallback.",
    "Small plan validator: valid structure, non-empty steps and allowed stage names.",
    "Generic LangGraph Plan-and-Execute graph.",
    "Demonstration handlers only; no EFRM access.",
    "Five application tables and LangGraph PostgreSQL checkpoints.",
    "Basic success, bypass, fallback, failure and restart tests.",
]: story.append(bullet(x))
story += [h2("10.2 Explicitly exclude")]
for x in [
    "Agent version and workflow version resolution.",
    "Institution-specific configuration registry beyond basic request ownership.",
    "Case, alert, transaction, device, match or rule data access.",
    "Rule health, decay, threshold, overlap or leakage analytics.",
    "Recommendations, review UI, RAG, candidate rules and simulation.",
    "Temporal, Kafka, Celery, Java and Spring Boot.",
    "Complex policy engine, outbox, dead-letter queue and production audit framework.",
]: story.append(bullet(x))
story += [h2("10.3 MVP configuration")]
story += [
    P("To keep the first PR small, core settings may be stored in environment variables or a simple application configuration file. Normal API callers do not manually select Planner mode."),
]
story += table(
    ["Setting", "Meaning"],
    [
        ["planner_enabled", "If true, call the LLM Planner. If false, load the fixed plan."],
        ["planner_model", "Configured model deployment used only by the Planner."],
        ["fixed_plan_path", "Approved JSON plan used for bypass or fallback."],
        ["allowed_stage_codes", "Small allow-list of demonstration stages."],
        ["checkpoint_database_url", "Dedicated connection/search path for langgraph_ckpt."],
    ],
    [52 * mm, 122 * mm],
)

# 11
story += [PageBreak(), h1("11. First-PR execution story")]
story += [mvp_sequence_diagram(), P("Figure 2. First-PR request, planning and execution sequence", "Captionx")]
mvp_steps = [
    ("Client triggers the API", "POST /v1/agent-invocations receives request_id, institution context and a small input object."),
    ("API creates the invocation", "Store agent_invocation with status QUEUED and return HTTP 202 immediately."),
    ("Worker finds queued work", "The one MVP background worker polls for QUEUED records."),
    ("Worker claims the invocation", "Atomically change QUEUED to RUNNING so the same invocation cannot be started twice."),
    ("Worker reads simple runtime settings", "Read planner_enabled, model setting, fixed plan location, graph key and allowed stages from configuration."),
    ("Plan is prepared", "If Planner is enabled, call the LLM. If bypassed, load the fixed plan. If LLM fails, load fixed fallback."),
    ("Plan is saved", "Persist execution_plan and, when the LLM was called, model_execution."),
    ("Graph run is created", "Create graph_run with its LangGraph thread_id and status RUNNING."),
    ("Initial graph state is built", "Put invocation IDs, plan, current index, small context, results and status into state."),
    ("Worker calls LangGraph", "The worker invokes the compiled graph with the initial state and thread_id."),
    ("LangGraph executes the plan", "Load plan, run one handler at a time, update state and route until complete or failed."),
    ("Checkpoints are written", "LangGraph saves recoverable state after graph steps."),
    ("Final result returns to worker", "The graph returns COMPLETED or FAILED state."),
    ("Worker saves final status", "Update graph_run and agent_invocation. The status API can now return the result."),
]
for i, (name, desc) in enumerate(mvp_steps, 1):
    story.append(numbered(i, f"<b>{name}:</b> {desc}"))
story += [h2("11.1 One worker clarification")]
story += [
    P("The MVP deploys one background worker. 'Worker' and 'background worker' are the same component. The claim operation is still atomic so a restart or future second replica cannot start the same queued invocation twice."),
]

# 12
story += [PageBreak(), h1("12. LangGraph Plan-and-Execute behavior")]
story += [langgraph_loop_diagram(), P("Figure 3. Generic state loop inside LangGraph", "Captionx")]
story += [h2("12.1 Graph state")]
story += table(
    ["State item", "Purpose"],
    [
        ["invocation_id and graph_run_id", "Connect state to application records."],
        ["plan_id and plan", "Identify the saved plan and its ordered steps."],
        ["current_step_index", "Tell the executor which plan step is next."],
        ["current_step_id and stage_code", "Identify the step currently running."],
        ["context", "Small values shared between demonstration handlers."],
        ["step_results", "Append results from completed steps."],
        ["status and error", "Represent RUNNING, COMPLETED or FAILED state."],
        ["final_result", "Return the final graph output."],
    ],
    [58 * mm, 116 * mm],
)
story += [h2("12.2 Nodes")]
story += table(
    ["Node", "What happens"],
    [
        ["load_plan", "Confirm the plan exists, has at least one step and uses allowed stage codes."],
        ["execute_step", "Read current_step_index, select one plan step, find its approved Python handler and execute it."],
        ["route_after_step", "If failed, go to fail. If more steps exist, loop. If finished, go to finalize."],
        ["finalize", "Build final result, set COMPLETED and finish the graph."],
        ["fail", "Build failure result, set FAILED and finish the graph."],
    ],
    [48 * mm, 126 * mm],
)
story += [h2("12.3 How state moves")]
for i, text in enumerate([
    "Worker creates state with current_step_index = 0 and an empty result list.",
    "load_plan checks the plan and passes state to execute_step.",
    "execute_step reads step 0 and calls the registered demonstration handler.",
    "The handler returns a small result and optional context updates.",
    "The node appends the result and changes current_step_index to 1.",
    "The router sees another step and sends the updated state back to execute_step.",
    "The loop continues until the index equals the number of plan steps.",
    "finalize creates the final result and LangGraph returns it to the worker.",
], 1): story.append(numbered(i, text))
story += [callout("Handler safety", "The LLM chooses from allowed stage codes. It does not supply Python code or arbitrary function names. A registry maps approved stage codes to approved Python handlers.")]

# 13
story += [h1("13. Minimum first-PR database model")]
story += [mvp_db_diagram(), P("Figure 4. Minimum application records and LangGraph checkpoint relationship", "Captionx")]
story += [callout("MVP database decision", "Not all 95 tables from the enterprise Agentic DB are required. First PR uses five application tables plus four LangGraph-managed checkpoint tables.", PALE_TEAL, TEAL)]
story += [h2("13.1 Application-managed tables")]
story += table(
    ["Table", "What it stores", "Why it is needed"],
    [
        ["agent_invocation", "request_id, institution_id, input, status, correlation ID, result, error and timestamps.", "Main record for the API-triggered execution. UNIQUE(request_id) provides basic duplicate protection."],
        ["execution_plan", "invocation ID, plan source, plan JSON, hash, status and creation time.", "Provides the exact LLM, fixed or fallback plan passed to LangGraph."],
        ["model_execution", "Planner model/provider, purpose, status, request/response hashes, latency, tokens, error and fallback flag.", "Shows when and how the LLM Planner was used. No row is needed when Planner is bypassed."],
        ["graph_run", "invocation ID, thread ID, graph key, status, current node, result, error and timestamps.", "Represents the overall LangGraph execution and links it to checkpoints."],
        ["graph_node_execution", "graph run, node, plan step, attempt, status, small input/output, error and timestamps.", "Shows which graph node or plan step ran and where an MVP failure occurred."],
    ],
    [39 * mm, 68 * mm, 67 * mm],
)
story += [h2("13.2 LangGraph-managed tables")]
story += table(
    ["Table", "Contents"],
    [
        ["langgraph_ckpt.checkpoints", "Serialized graph state by thread and checkpoint."],
        ["langgraph_ckpt.checkpoint_blobs", "Larger channel values used by checkpoints."],
        ["langgraph_ckpt.checkpoint_writes", "Intermediate node writes."],
        ["langgraph_ckpt.checkpoint_migrations", "Runtime checkpoint schema version."],
    ],
    [63 * mm, 111 * mm],
)
story += [h2("13.3 Tables deliberately deferred")]
story += [
    P("A separate idempotency table is not required in the MVP because agent_invocation.request_id is unique. A formal audit table, graph transitions, signals, outbox, dead-letter queue, artifact model, agent/workflow registries and all Rule Optimizer business tables are deferred."),
]
story += [h2("13.4 Record creation flow")]
story += [code(
"API                 -> agent_invocation (QUEUED)\n"
"Worker claims       -> agent_invocation (RUNNING)\n"
"LLM Planner         -> model_execution (only when invoked)\n"
"Plan preparation    -> execution_plan\n"
"Graph starts        -> graph_run (RUNNING)\n"
"Each node           -> graph_node_execution\n"
"Graph checkpoints   -> langgraph_ckpt.*\n"
"Graph returns       -> graph_run + agent_invocation (COMPLETED/FAILED)"
)]

# 14
story += [h1("14. First-PR APIs, worker and configuration")]
story += [h2("14.1 Trigger API")]
story += table(
    ["Item", "MVP contract"],
    [
        ["Endpoint", "POST /v1/agent-invocations"],
        ["Input", "request_id and a small input object; institution/actor comes from trusted backend context."],
        ["Processing", "Create QUEUED agent_invocation if request_id is new."],
        ["Output", "HTTP 202 with invocation_id and QUEUED status."],
        ["Does not do", "It does not wait for the Planner or LangGraph execution."],
    ],
    [45 * mm, 129 * mm],
)
story += [h2("14.2 Status API")]
story += table(
    ["Item", "MVP contract"],
    [
        ["Endpoint", "GET /v1/agent-invocations/{invocation_id}"],
        ["Output", "Invocation status, plan source, graph status, current node, final result or error."],
        ["Source", "Read application tables, not LangGraph internals directly."],
    ],
    [45 * mm, 129 * mm],
)
story += [h2("14.3 Background worker")]
for x in [
    "Poll one QUEUED invocation.",
    "Atomically claim it by changing QUEUED to RUNNING only if it is still QUEUED.",
    "Read simple runtime configuration.",
    "Call the LLM Planner or load the fixed plan.",
    "Save the plan and create graph_run.",
    "Invoke the compiled LangGraph with the plan state and thread_id.",
    "Save COMPLETED or FAILED status after the graph returns.",
]: story.append(bullet(x))
story += [h2("14.4 Demonstration stages")]
story += table(
    ["Stage", "MVP behavior"],
    [
        ["initialise_context", "Place a small initial marker into graph context."],
        ["demo_processing", "Perform a harmless transformation of demonstration input."],
        ["complete", "Return a successful demonstration result."],
    ],
    [55 * mm, 119 * mm],
)

# 15
story += [h1("15. First-PR acceptance criteria and test plan")]
acceptance = [
    "POST creates exactly one invocation for a new request_id and returns HTTP 202.",
    "A repeated request_id returns or identifies the existing invocation rather than creating another run.",
    "The one background worker claims and processes a QUEUED invocation.",
    "When Planner is enabled, the LLM returns a structured plan and model_execution is recorded.",
    "When Planner is bypassed, the fixed plan is used and no LLM call is made.",
    "When the LLM times out or returns an invalid plan, the fixed fallback plan is used and the graph still runs.",
    "The plan is stored before LangGraph execution begins.",
    "LangGraph executes every demonstration step in order.",
    "Each graph node attempt is visible in graph_node_execution.",
    "The current node and final graph status are visible through the status API.",
    "A simulated worker restart can recover graph state from PostgreSQL checkpoints.",
    "No EFRM database, Rule Engine, transaction, case, alert or rule table is accessed.",
]
for i, x in enumerate(acceptance, 1): story.append(numbered(i, x))
story += [h2("15.1 Minimum test cases")]
story += table(
    ["Test", "Expected result"],
    [
        ["Happy path with LLM Planner", "LLM plan saved; graph executes; invocation completes."],
        ["Planner bypass", "Fixed plan saved; no model_execution; graph completes."],
        ["Planner timeout", "Failed model_execution; FIXED_FALLBACK plan; graph completes."],
        ["Invalid stage", "Plan rejected; fixed fallback used or invocation fails according to selected MVP policy."],
        ["Duplicate request", "No second invocation is created."],
        ["Node handler error", "graph_run and invocation become FAILED with the failed node recorded."],
        ["Worker restart", "Same graph thread resumes from stored checkpoint or safely restarts according to test configuration."],
        ["Status polling", "GET shows QUEUED, RUNNING and final status transitions."],
    ],
    [54 * mm, 120 * mm],
)

# 16
story += [h1("16. Implementation sequence and repository structure")]
impl = [
    ("Project skeleton", "Create FastAPI application, settings, database connection and health endpoint."),
    ("MVP migrations", "Create five application tables and add UNIQUE(request_id)."),
    ("Checkpoint setup", "Configure langgraph_ckpt connection and run LangGraph checkpointer setup during deployment."),
    ("Trigger API", "Create QUEUED invocation and return HTTP 202."),
    ("Worker", "Implement one polling process and atomic claim."),
    ("Planner", "Implement LLM structured-output request and record model execution."),
    ("Fixed plan", "Add approved JSON plan and fallback loader."),
    ("Plan validator", "Check structure, non-empty steps and stage allow-list."),
    ("LangGraph", "Implement state, load_plan, execute_step, route, finalize and fail."),
    ("Node records", "Record node start, completion and failure."),
    ("Status API", "Return application-level execution state."),
    ("Tests and README", "Cover acceptance scenarios and explain how to run API and worker."),
]
for i, (name, desc) in enumerate(impl, 1): story.append(numbered(i, f"<b>{name}:</b> {desc}"))
story += [h2("16.1 Suggested repository structure")]
story += [code(
"app/\n"
"  api/agent_invocations.py\n"
"  planner/llm_planner.py\n"
"  planner/fixed_plan_loader.py\n"
"  planner/validator.py\n"
"  graph/state.py\n"
"  graph/nodes.py\n"
"  graph/routing.py\n"
"  graph/builder.py\n"
"  graph/handlers.py\n"
"  worker/worker.py\n"
"  worker/invocation_processor.py\n"
"  repositories/\n"
"  database/\n"
"  settings.py\n"
"  main.py\n"
"plans/rule_optimizer_mvp.json\n"
"tests/"
)]

# 17
story += [h1("17. Deferred work and subsequent PR roadmap")]
story += table(
    ["PR/Stage", "Scope"],
    [
        ["PR 1 - current", "Generic Plan-and-Execute MVP only."],
        ["PR 2", "False-positive trigger/poller, outcome mapping and case verification against approved EFRM read boundary."],
        ["PR 3", "Case-alert-result-match lineage and source-aware rule/version selection."],
        ["PR 4", "Rule configuration bundle and historical/current version resolution."],
        ["PR 5", "Snapshot plan/build, Parquet storage, manifest and data-quality gates."],
        ["PR 6", "Deterministic health, decay, threshold and overlap analytics."],
        ["PR 7", "Deterministic strategy, optional LLM explanation, recommendation composition and validation."],
        ["PR 8", "Recommendation API/UI integration, reviewer decisions, audit, outbox and operational hardening."],
        ["Future", "Candidate generation, JSON-to-DRL compiler integration, simulator verification and historical backtesting."],
    ],
    [42 * mm, 132 * mm],
)
story += [h2("17.1 Shared platform hardening deferred from MVP")]
for x in [
    "Agent/workflow/model/tool version registries and activation bindings.",
    "Row-level security, full tenant-aware foreign keys and enterprise authorization decisions.",
    "Outbox publication, dead-letter processing, cancellation signals and worker leases/heartbeats.",
    "Formal audit partitioning and append-only lifecycle controls.",
    "Object-storage artifacts, evidence graphs, claim validation and retention/legal hold.",
    "RAG ingestion, pgvector and document permissions.",
]: story.append(bullet(x))

# 18
story += [h1("18. Open inputs and risks")]
story += table(
    ["Open input", "Why it matters", "Owner/next action"],
    [
        ["LLM provider and deployment", "Planner implementation needs endpoint, authentication, model and structured-output capability.", "Platform/AI architecture approval."],
        ["Planner enabled default", "Decides whether PR demo uses LLM first or fixed plan first.", "Manager decision; configuration, not API user choice."],
        ["Fixed plan content", "Must define approved demonstration stages and expected order.", "Rule Optimizer developer + platform lead."],
        ["MVP table DDL approval", "execution_plan is proposed; enterprise DB v1.1 may require different naming/dependencies.", "Database owner."],
        ["Authentication context", "institution_id and actor must come from trusted middleware, not arbitrary request JSON.", "Platform/API team."],
        ["Worker deployment", "Need process/container startup, health and database credentials.", "DevOps/platform."],
        ["Checkpoint DSN and schema", "LangGraph runtime tables require dedicated setup and search path.", "Database/platform team."],
        ["EFRM read contract", "Required only after PR 1 for real optimizer data.", "EFRM product/database owners."],
        ["Metric and outcome policies", "Required before analytics can make defensible findings.", "Fraud/risk/product owners."],
    ],
    [45 * mm, 75 * mm, 54 * mm],
)
story += [h2("18.1 Main risks")]
for x in [
    "Scope creep: adding real optimizer tools before the Plan-and-Execute MVP is accepted.",
    "Confusing LangGraph checkpoints with application reporting tables.",
    "Letting the LLM choose arbitrary code or tools instead of allowed stage codes.",
    "Making Planner failure block execution despite the agreed fixed fallback.",
    "Treating sample database row counts as production sizing evidence.",
    "Claiming fraud recall or true leakage without confirmed independent outcome labels.",
    "Assuming deleted historical rules can be reconstructed without source evidence.",
]: story.append(bullet(x))

# 19
story += [h1("19. Decision log")]
story += table(
    ["Topic", "Final decision"],
    [
        ["Repository boundary", "Agentic Platform is separate from the existing EFRM product and supports multiple agents."],
        ["Rule selection", "Analyze only rules traced from finalized false-positive cases, not every rule."],
        ["Outcome precedence", "Final case decision overrides conflicting alert-level decision."],
        ["Institution/channel", "Configuration-driven and neutral; no pilot institution or channel is fixed."],
        ["Data access", "Predefined parameterized SQL tools against EFRM read-only boundary for current Phase 1."],
        ["Dynamic SQL", "Not used by the Rule Optimizer. Restricted safe-query fallback belongs to other controlled use cases."],
        ["Analytics owner", "Python/SQL calculate official findings; LLM does not calculate metrics."],
        ["LLM explanation", "Optional and evidence-bounded after deterministic findings."],
        ["Planner", "LLM-only when invoked, but invocation is optional at workflow level."],
        ["Planner selection", "Workflow configuration selects mode automatically; normal users do not choose it."],
        ["Planner failure", "Use approved fixed fallback and continue."],
        ["Workflow", "LangGraph; no Temporal."],
        ["Phase 1 output", "Recommendation only; no direct rule write."],
        ["RAG", "Future policy/document support only; not operational source of truth."],
        ["MVP worker", "One background worker process; atomic claim supports safe future scaling."],
        ["MVP versions", "No agent-version or workflow-version resolution in first PR."],
        ["MVP database", "Five application tables plus four LangGraph-managed checkpoint tables."],
    ],
    [52 * mm, 122 * mm],
)

# 20
story += [h1("20. Handover checklist and glossary")]
story += [h2("20.1 Before starting implementation")]
checklist = [
    "Confirm the team accepts the five-table MVP model or supplies the exact approved DDL.",
    "Confirm LLM provider/model and secret-management approach.",
    "Confirm whether planner_enabled defaults to true for the demo.",
    "Approve the fixed demonstration plan and allowed stage codes.",
    "Confirm FastAPI authentication assumptions and trusted institution context.",
    "Create application and checkpoint PostgreSQL connections.",
    "Agree on worker startup command and local development process.",
    "Create PR acceptance tests before adding future optimizer scope.",
]
for i, x in enumerate(checklist, 1): story.append(numbered(i, x))
story += [h2("20.2 Definition of done for handoff")]
for x in [
    "A new developer can explain the difference between enterprise target and first-PR MVP.",
    "They know the worker, not FastAPI, invokes LangGraph.",
    "They know the Planner is LLM-only when invoked and fixed plan is the bypass/fallback.",
    "They know the plan becomes LangGraph state and execute_step loops through allowed handlers.",
    "They know which five application tables are required now and which four are runtime-managed.",
    "They know EFRM data access and all Rule Optimization analytics are deferred to later PRs.",
]: story.append(bullet(x))
story += [h2("20.3 Glossary")]
story += table(
    ["Term", "Meaning"],
    [
        ["Invocation", "One API-triggered request to run an agent workflow."],
        ["Planner", "Optional LLM component that creates a structured ordered plan."],
        ["Fixed plan", "Approved JSON plan used when Planner is bypassed."],
        ["Fallback plan", "The same approved fixed plan used after Planner failure."],
        ["Background worker", "Separate Python process that claims queued work and calls LangGraph."],
        ["LangGraph state", "Small shared working object passed and checkpointed between graph nodes."],
        ["Node", "Python function representing one graph step such as load, execute or finalize."],
        ["Handler", "Approved Python function mapped from an allowed plan stage code."],
        ["Checkpoint", "Saved LangGraph execution state used for recovery."],
        ["Snapshot", "Future bounded historical analytical population for one rule/version and policy."],
        ["Recommendation", "Human-review output; never an automatic production rule change."],
    ],
    [42 * mm, 132 * mm],
)
story += [
    Spacer(1, 8),
    callout("Final handover statement", "Start implementation with the first-PR Plan-and-Execute MVP. Do not add EFRM data tools, optimizer analytics or recommendation logic until the MVP is reviewed and accepted.", PALE_TEAL, TEAL),
]


doc = HandoverDoc(str(OUT))
doc.build(story)
print(OUT)
