package com.worldremit.consumers;

import org.apache.kafka.streams.kstream.KStream;
import org.springframework.cloud.stream.annotation.Input;
import org.springframework.cloud.stream.annotation.Output;

public interface GirosProcessor {
    String GIROS = "giros";

    String OUTPUT = "merged";

    @Input(GirosProcessor.GIROS)
    KStream<?,?> input();

    @Output(GirosProcessor.OUTPUT)
    KStream<?,?> output();
}
