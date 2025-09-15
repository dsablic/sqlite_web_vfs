FROM amazonlinux:2023

ENV LANG=C.UTF-8
RUN dnf -y update && dnf -y install \
    ruby ruby-devel gcc gcc-c++ clang make \
    sqlite-devel libcurl-devel \
    && dnf clean all

WORKDIR /app
COPY . /app

RUN gem install --no-document rake rspec sqlite3 sqlite3-ffi
RUN gem build sqlite_web_vfs.gemspec && \
    CXX=g++12 CXXFLAGS="-std=gnu++17" \
    gem install --no-document ./sqlite_web_vfs-*.gem || \
    (echo 'Falling back to clang++'; CXX=clang++ CXXFLAGS="-std=gnu++17" gem install --no-document ./sqlite_web_vfs-*.gem)

CMD ["bash", "-lc", "rspec -fd spec/integration"]
