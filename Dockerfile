FROM mcr.microsoft.com/azure-cli:latest     
RUN mkdir /app
WORKDIR /app
ENV SUBSCRIPTION_ID=""
ADD stop.sh /app/stop.sh
RUN  chmod +x /app/stop.sh
CMD [ "/app/stop.sh" ]
