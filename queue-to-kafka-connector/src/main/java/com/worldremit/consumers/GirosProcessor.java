package com.worldremit.consumers;

import org.springframework.cloud.stream.annotation.Input;
import org.springframework.messaging.SubscribableChannel;

public interface GirosProcessor {
    String GIROS = "giros";

    @Input(GirosProcessor.GIROS)
    SubscribableChannel giros();
}
