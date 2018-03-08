FROM chia7712/kafka:base

# INSTALL openssh
RUN apt-get install -y openssh-server openssh-client

# CLONE hquick
RUN mkdir $COMPONENT_HOME/hquick
RUN git clone https://github.com/chia7712/hquick.git $COMPONENT_HOME/hquick

# Set ENV
ENV HQUICK_HOME=$COMPONENT_HOME/hquick
ENV PATH=$PATH:$HQUICK_HOME/bin