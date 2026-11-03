import { REPORT_STATUS_LABELS, type AiReportStatus } from "@/lib/api";
import { Badge, COLORS } from "./ui";

export default function ReportStatusBadge({ status }: { status: AiReportStatus }) {
  const [color, bg] =
    status === "draft"
      ? [COLORS.warnText, COLORS.warnSoft]
      : status === "sent"
        ? [COLORS.primaryDark, COLORS.primarySoft]
        : [COLORS.successText, COLORS.successSoft];
  return <Badge color={color} bg={bg}>{REPORT_STATUS_LABELS[status]}</Badge>;
}
