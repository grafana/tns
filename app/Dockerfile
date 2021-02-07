FROM maven:3.6.3-openjdk-11 as build
WORKDIR /usr/src/app

# We copy the pom and install the dependencies as a sepearate step so docker will cache them.
COPY pom.xml /usr/src/app
RUN mvn dependency:resolve

# Now actually build the thing.
COPY src /usr/src/app/src
RUN mvn install -Dmaven.test.skip=true


FROM tomcat:9-jre11
RUN curl -L -o /usr/local/tomcat/opentelemetry-javaagent-all.jar https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v0.15.1/opentelemetry-javaagent-all.jar
COPY --from=build /usr/src/app/target/News.war /usr/local/tomcat/webapps/News.war
ENV JAVA_OPTS="-javaagent:/usr/local/tomcat/opentelemetry-javaagent-all.jar -Dlogging.level.org.springframework.web.filter.CommonsRequestLoggingFilter=DEBUG '-Dlogging.pattern.console=%d{yyyy-MM-dd HH:mm:ss} - %logger{36} - %msg traceID=%X{traceId} %n'"
