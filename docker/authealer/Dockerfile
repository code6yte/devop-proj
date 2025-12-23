FROM alpine:3.18

RUN apk add --no-cache docker-cli bash curl jq

# Copy the authealer script
WORKDIR /ansible
COPY ansible/authealer.sh /ansible/authealer.sh
RUN chmod +x /ansible/authealer.sh

CMD ["/ansible/authealer.sh"]
