// Dynatrace Workflows → Run JavaScript

// 1) Import your library (ESM) from GitHub raw:
const LIB_URL = "https://raw.githubusercontent.com/ashu-mroads/sox-js-library/main/sox-workflow.mjs";
import * as sox from LIB_URL;

// Optional SDK to read run params:
import { execution } from "@dynatrace-sdk/automation-utils"; // lets you read ex.params
// (Docs confirm usage of `execution()` in Run JS.) :contentReference[oaicite:1]{index=1}

export default async function ({ executionId }) {
    const ex = await execution(executionId);
    const p = ex?.params ?? {};

    // ---- Inputs you can pass as Workflow "Run parameters" (JSON) ----
    const sourceIntegrationId = p.sourceIntegrationId ?? "int15-3-2";
    const destinationIntegrationId = p.destinationIntegrationId ?? "int15-3-1";
    const sourcePayload = p.sourcePayload ?? { confirmationIds: [{ value: "A1B2C3" }], propertyCode: "ABC" };
    const destinationPayload = p.destinationPayload ?? sourcePayload;
    const ingest = !!p.ingest; // set true to ingest a Business Event

    // Show what the library exports (helps verify you loaded the right file)
    const available = Object.keys(sox).sort();

    // A) Validate one integration (if the method exists)
    const single = typeof sox.validateIntegration === "function"
        ? sox.validateIntegration({
            integrationId: sourceIntegrationId,
            payload: {
                sox_integration: sourceIntegrationId,
                sox_transaction_timestamp: new Date().toISOString(),
                sox_transaction_id: crypto.randomUUID(),
                sox_data: { success: 1, payload: sourcePayload }
            }
        })
        : { skipped: true, reason: "validateIntegration not exported" };

    // B) Validate a source→destination pair (if the method exists)
    const pair = typeof sox.validateIntegrationPair === "function"
        ? sox.validateIntegrationPair({
            sourceIntegrationId,
            destinationIntegrationId,
            sourcePayload,
            destinationPayload
        })
        : { skipped: true, reason: "validateIntegrationPair not exported" };

    // C) Build a CloudEvent preview (if available)
    const cloudEvent = typeof sox.toCloudEvent === "function"
        ? sox.toCloudEvent({
            eventType: pair?.errors?.length ? "Error" : "OK",
            eventId: crypto.randomUUID(),
            timestamp: Date.now(),
            transactionId: crypto.randomUUID(),
            sourceIntId: sourceIntegrationId,
            destIntId: destinationIntegrationId,
            srcEventTime: new Date().toISOString(),
            destEventTime: new Date().toISOString(),
            errorType: pair?.errors?.[0]?.type,
            errorSubType: pair?.errors?.[0]?.subType,
            errorSummary: pair?.errors?.[0]?.message,
            sourceData: JSON.stringify(sourcePayload),
            destinationData: JSON.stringify(destinationPayload)
        })
        : { skipped: true, reason: "toCloudEvent not exported" };

    // D) Optional: ingest as a Business Event (requires storage:events:write)
    // (`businessEventsClient.ingest` is the official way to ingest CloudEvents.) :contentReference[oaicite:2]{index=2}
    let ingestResult = { skipped: true };
    if (ingest && typeof sox.createBusinessEvent === "function") {
        ingestResult = await sox.createBusinessEvent(
            cloudEvent?.data ?? cloudEvent // depending on your helper’s return shape
        );
    }

    return { usedUrl: LIB_URL, available, single, pair, cloudEvent, ingestResult };
}
