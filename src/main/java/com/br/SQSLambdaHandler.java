package com.br;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.br.service.ImageProcessingService;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import org.jboss.logging.Logger;

@Named("image-processor")
public class SQSLambdaHandler implements RequestHandler<SQSEvent, Void> {

    private static final Logger LOG = Logger.getLogger(SQSLambdaHandler.class);

    @Inject
    ImageProcessingService processingService;

    @Override
    public Void handleRequest(SQSEvent event, Context context) {
        for (SQSEvent.SQSMessage message : event.getRecords()) {
            try {
                processingService.process(message.getBody());
            } catch (Exception e) {
                LOG.errorf(e, "Failed to process SQS message %s", message.getMessageId());
                // Re-throw so SQS retries the message (up to maxReceiveCount, then DLQ)
                throw new RuntimeException("Processing failed for message " + message.getMessageId(), e);
            }
        }
        return null;
    }
}
