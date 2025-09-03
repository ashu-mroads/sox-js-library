// Example usage with the NEW CreateBusinessEvent(high-level) helper.
// Steps:
// 1. Build source & destination SOX wrappers
// 2. Run validateIntegrationPair
// 3. Call CreateBusinessEvent (it classifies errors, builds SoxBusinessEvent, ingests)
// NOTE: Until index.ts is updated to re-export CreateBusinessEvent, import it directly.

import { validateIntegrationPair } from '../src/index.js';
import { CreateBusinessEvent } from '../src/common/dynatrace.bizevents.js';

// ---- Sample wrapper payloads (adjust to satisfy your rule maps) ----
const sourceWrapper = {
    sox_integration: 'int15-3-2',
    sox_transaction_id: 'TX-12345',
    sox_transaction_timestamp: new Date().toISOString(),
    content: {
        success: 1,
        payload: {
            candidate: {
                id: 'CAND-001',
                firstName: 'Alice',
                lastName: 'Doe'
            }
        }
    }
};

const destinationWrapper = {
    sox_integration: 'int15-3-1',
    sox_transaction_id: 'TX-12345',
    sox_transaction_timestamp: new Date().toISOString(),
    content: {
        success: 1,
        payload: {
            candidate: {
                id: 'CAND-001',
                firstName: 'Alice',
                lastName: 'Doe'
            }
        }
    }
};

async function run() {
    // 1. Validate the integration pair
    const validationResult = validateIntegrationPair({
        sourceIntegrationId: sourceWrapper.sox_integration,
        destinationIntegrationId: destinationWrapper.sox_integration,
        sourcePayload: sourceWrapper,
        destinationPayload: destinationWrapper
    });

    console.log('Pair validation summary:', {
        isValid: validationResult.isValid,
        errors: validationResult.errors,
        sourceFailures: validationResult.sourceValidation?.failures.length,
        destinationFailures: validationResult.destinationValidation?.failures.length,
        mapping: validationResult.mappingComparison && {
            missingSource: validationResult.mappingComparison.missingSource,
            missingDestination: validationResult.mappingComparison.missingDestination,
            mismatches: validationResult.mappingComparison.mismatches
        }
    });

    // 2. Use high-level CreateBusinessEvent builder+ingester
    const ingestResult = await CreateBusinessEvent({
        validationResult,
        transactionId: sourceWrapper.sox_transaction_id,
        srcEventTime: sourceWrapper.sox_transaction_timestamp,
        destEventTime: destinationWrapper.sox_transaction_timestamp,
        sourcePayload: sourceWrapper.content.payload,
        destinationPayload: destinationWrapper.content.payload
    });

    // 3. Output result
    console.log('Ingest outcome:', {
        success: ingestResult.success,
        status: ingestResult.status,
        message: ingestResult.message,
        truncated: {
            source: ingestResult.sourceDataTruncated,
            destination: ingestResult.destinationDataTruncated
        },
        eventType: ingestResult.cloudEvent.type,
        errorType: ingestResult.cloudEvent.data?.errorType,
        errorSubType: ingestResult.cloudEvent.data?.errorSubType,
        errorSummary: ingestResult.cloudEvent.data?.errorSummary
    });

    if (!ingestResult.success) {
        console.error('Ingest error detail:', ingestResult.error);
    }
}

run().catch(e => console.error('Unhandled failure:', e));