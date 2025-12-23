FROM alpine:3.18

RUN apk add --no-cache docker-cli bash curl jq

# Copy the authealer script
COPY ansible/authealer.sh /usr/local/bin/authealer.sh
RUN chmod +x /usr/local/bin/authealer.sh

CMD ["/usr/local/bin/authealer.sh"]
