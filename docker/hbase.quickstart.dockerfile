FROM chia7712/hbase:base

# CLONE cquick
RUN mkdir $COMPONENT_HOME/cquick
RUN git clone https://github.com/chia7712/cquick.git $COMPONENT_HOME/cquick

# Set ENV
ENV CQUICK_HOME=$COMPONENT_HOME/cquick
ENV PATH=$PATH:$CQUICK_HOME/bin
