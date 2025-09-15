FROM amazonlinux:2023

ENV LANG=C.UTF-8
RUN dnf -y update && dnf -y install \
    ruby ruby-devel gcc gcc-c++ make \
    sqlite-devel libcurl-devel \
    && dnf clean all

WORKDIR /app
COPY . /app

RUN gem install bundler:2.5.9 && bundle init && \
    echo "gem 'rake'" >> Gemfile && \
    echo "gem 'rspec'" >> Gemfile && \
    echo "gem 'sqlite3'" >> Gemfile && \
    echo "gem 'sqlite3-ffi'" >> Gemfile && \
    bundle install
RUN gem build sqlite_web_vfs.gemspec && gem install ./sqlite_web_vfs-*.gem

CMD ["bash", "-lc", "rspec -fd spec/integration"]
