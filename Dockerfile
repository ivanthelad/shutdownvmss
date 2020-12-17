FROM mcr.microsoft.com/azure-cli:latest     
RUN mkdir /app
WORKDIR /app
ENV SUBSCRIPTION_ID=""
## comman seperated list of RGs to inlcude in the shutdown
ENV INCLUDE_RG=""
## comma seperated list of RGs to exclude in the shutdown 
## EXCLUDE_RG="rg1,rg2,rg3"
ENV EXCLUDE_RG=""
ENV USE_MSI=true
ADD stop.sh /app/stop.sh
RUN  chmod +x /app/stop.sh
CMD [ "/app/stop.sh" ]
