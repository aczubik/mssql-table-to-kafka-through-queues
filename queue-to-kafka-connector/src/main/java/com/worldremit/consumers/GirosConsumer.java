package com.worldremit.consumers;

import org.apache.kafka.streams.kstream.KStream;
import org.springframework.cloud.stream.annotation.EnableBinding;
import org.springframework.cloud.stream.annotation.Input;
import org.springframework.cloud.stream.annotation.StreamListener;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.stereotype.Component;

@Component
@EnableBinding(GirosProcessor.class)
public class GirosConsumer {

    @StreamListener
    @SendTo(GirosProcessor.OUTPUT)
    public KStream<?,Giros> handle(@Input(GirosProcessor.GIROS) KStream<String,Giros> stream) {
        return stream;
    }

}
