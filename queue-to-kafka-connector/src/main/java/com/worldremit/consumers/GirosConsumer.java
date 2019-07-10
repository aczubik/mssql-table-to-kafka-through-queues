package com.worldremit.consumers;

import org.springframework.cloud.stream.annotation.EnableBinding;
import org.springframework.cloud.stream.annotation.StreamListener;
import org.springframework.stereotype.Component;

@Component
@EnableBinding(GirosProcessor.class)
public class GirosConsumer {

    @StreamListener(GirosProcessor.GIROS)
    public void handle(Giros value) {
        System.out.println(value.getId());
        System.out.println(value.getName());
    }

}
