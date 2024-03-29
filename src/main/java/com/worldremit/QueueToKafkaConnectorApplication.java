package com.worldremit;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.worldremit.consumers.GirosProcessor;
import lombok.Data;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.apache.kafka.connect.json.JsonSerializer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaAdmin;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ProducerFactory;

import javax.persistence.*;
import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Entity
@Data
class Event {
    @Id
    @Column(name = "conversation_handle")
    private UUID conversationHandle;
    @Column(name = "message_body")
    private byte[] messageBody;
    @Column(name = "message_type_name")
    private String messageTypeName;
}

class EventValue {
    @JsonProperty("id")
    private UUID id;
    @JsonProperty("row")
    private String row;
    @JsonProperty("tracking_type")
    private String trackingType;

    public String getRow() {
        return row;
    }

    public UUID getId() {
        return id;
    }
}

@Configuration
class KafkaTopicConfig {

    @Value(value = "${kafka.bootstrapAddress}")
    private String bootstrapAddress;

    @Bean
    public KafkaAdmin kafkaAdmin() {
        Map<String, Object> configs = new HashMap<>();
        configs.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapAddress);
        return new KafkaAdmin(configs);
    }

    @Bean
    public NewTopic girosTopic() {
        return new NewTopic("giros", 1, (short) 1);
    }
}

@Configuration
class KafkaProducerConfig {

    @Value(value = "${kafka.bootstrapAddress}")
    private String bootstrapAddress;

    @Bean
    public ProducerFactory<String, Object> producerFactory() {
        Map<String, Object> configProps = new HashMap<>();
        configProps.put(
                ProducerConfig.BOOTSTRAP_SERVERS_CONFIG,
                bootstrapAddress);
        configProps.put(
                ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG,
                StringSerializer.class);
        configProps.put(
                ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG,
                JsonSerializer.class);
        return new DefaultKafkaProducerFactory<String, Object>(configProps);
    }

    @Bean
    public KafkaTemplate<String, Object> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }
}

class MsSqlQueueListener {

    private static final String END_CONVERSATION_MESSAGE_TYPE = "http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog";

    private static final String RECEIVE_QUERY = "waitfor(\n" +
            "        RECEIVE top (1) conversation_handle,service_name,message_type_name,message_body,message_sequence_number\n" +
            "        FROM [TargetQueue_giros]\n" +
            "        ), timeout 3000";

    private EntityManagerFactory emf;
    private KafkaTemplate<String, Object> kafkaTemplate;

    private final String sqlServerQueueName;

    public MsSqlQueueListener(String sqlServerQueueName, EntityManagerFactory emf, KafkaTemplate<String, Object> kafkaTemplate) {
        this.sqlServerQueueName = sqlServerQueueName;
        this.emf = emf;
        this.kafkaTemplate = kafkaTemplate;
    }

    public void waitForMessages() {
        EntityManager em = null;
        try {
            em = emf.createEntityManager();

            while (1 == 1) {

                EntityTransaction transaction = em.getTransaction();
                transaction.begin();

                try {
                    List<Event> events = em.createNativeQuery(RECEIVE_QUERY, Event.class).getResultList();
                    for (Event event : events) {
                        processEvent(event);
                    }
                    transaction.commit();
                    em.clear();
                } catch (Exception exception) {
                    transaction.rollback();
                    exception.printStackTrace();
                }
            }

        } catch (Exception exception) {
            if (em != null) {
                em.close();
            }
        }
    }

    private void processEvent(Event event) throws IOException {

        if (event.getMessageTypeName().equals(END_CONVERSATION_MESSAGE_TYPE)) {
            return;
        }

        String messageBody = new String(event.getMessageBody(), "UTF-16LE");
        System.out.println(messageBody);
        System.out.println(event);

        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
        EventValue eventValue = objectMapper.readValue(messageBody, EventValue.class);
        kafkaTemplate.send(GirosProcessor.GIROS, eventValue.getId().toString(), objectMapper.readTree(eventValue.getRow()));

    }
}

@SpringBootApplication
public class QueueToKafkaConnectorApplication {

    public static void main(String[] args) {
        SpringApplication.run(QueueToKafkaConnectorApplication.class, args);
    }

    @Autowired
    private MsSqlQueueListener msSqlQueueListener;

    @Bean
    public MsSqlQueueListener girosListener(EntityManagerFactory emf, KafkaTemplate<String, Object> kafkaTemplate) {
        return new MsSqlQueueListener("TargetQueue_giros", emf, kafkaTemplate);
    }

    @Bean
    ApplicationRunner applicationRunner() {
        return args -> {
            msSqlQueueListener.waitForMessages();
        };
    }

}
