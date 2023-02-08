FROM squidfunk/mkdocs-material:8.4.1

WORKDIR /docs
COPY ./requirements.txt .

RUN ls -la
RUN pip install -r requirements.txt

EXPOSE 8000
ENTRYPOINT ["mkdocs"]
CMD ["serve", "--dev-addr=0.0.0.0:8000"]
