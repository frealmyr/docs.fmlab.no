FROM squidfunk/mkdocs-material:9.1.17

WORKDIR /docs
COPY ./requirements.txt .

RUN ls -la
RUN pip install -r requirements.txt

EXPOSE 8000
ENTRYPOINT ["mkdocs"]
CMD ["serve", "--dev-addr=0.0.0.0:8000"]
