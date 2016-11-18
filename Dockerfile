FROM nanshe/nanshe_notebook:latest
MAINTAINER John Kirkham <jakirkham@gmail.com>

ADD nanshe_workflow /nanshe_workflow
RUN rm -rf /nanshe_workflow/.git
ADD .git/modules/nanshe_workflow /nanshe_workflow/.git
RUN sed -i.bak "s/..\/..\/..\/nanshe_workflow/../g" /nanshe_workflow/.git/config && \
    rm -f /nanshe_workflow/.git/config.bak && \
    sed -i.bak "/.*worktree = .*/d" /nanshe_workflow/.git/config && \
    rm -f /nanshe_workflow/.git/config.bak && \
    cd /nanshe_workflow && git update-index -q --refresh && cd /

ADD entrypoint.sh /usr/share/docker/entrypoint_2.sh

RUN for PYTHON_VERSION in 2 3; do \
        cd /nanshe_workflow && git update-index -q --refresh && cd / && \
        (mv /nanshe_workflow/.git/shallow /nanshe_workflow/.git/shallow-not || true) && \
        conda${PYTHON_VERSION} build /nanshe_workflow/nanshe_workflow.recipe && \
        (mv /nanshe_workflow/.git/shallow-not /nanshe_workflow/.git/shallow || true) && \
        conda${PYTHON_VERSION} install -qy --use-local -n root nanshe_workflow && \
        conda${PYTHON_VERSION} update -qy --use-local -n root --all && \
        conda${PYTHON_VERSION} remove -qy nanshe_workflow && \
        conda${PYTHON_VERSION} update -qy --use-local -n root --all && \
        pip${PYTHON_VERSION} install -e /nanshe_workflow && \
        python${PYTHON_VERSION} -m ipykernel install && \
        python${PYTHON_VERSION} -m ipyparallel.apps.ipclusterapp nbextension enable && \
        python${PYTHON_VERSION} -m notebook.nbextensions enable --sys-prefix --py widgetsnbextension && \
        rm -rf /opt/conda${PYTHON_VERSION}/conda-bld/work/* && \
        conda${PYTHON_VERSION} remove -qy -n _build_placehold_placehold_placehold_placehold_placehold_placeh --all && \
        conda${PYTHON_VERSION} remove -qy -n _test --all && \
        conda${PYTHON_VERSION} clean -tipsy ; \
    done

RUN python3 -m IPython profile create --parallel && \
    echo -e "import os\n\n\nc = get_config()\n\nc.IPClusterEngines.n = int(os.environ[\"CORES\"]) - 1" > /root/.ipython/profile_default/ipcluster_config.py && \
    echo -e "c = get_config()\n\nc.HubFactory.ip = '*'\nc.HubFactory.engine_ip = '*'\nc.HubFactory.db_class = \"SQLiteDB\"" > /root/.ipython/profile_default/ipcontroller_config.py && \
    echo -e "c = get_config()\n\nc.IPEngineApp.wait_for_url_file = 60\nc.EngineFactory.timeout = 60" > /root/.ipython/profile_default/ipengine_config.py && \
    python3 -m IPython profile create --parallel --profile=sge && \
    echo -e "import os\n\n\nc = get_config()\n\nc.IPClusterStart.controller_launcher_class = \"SGE\"\nc.IPClusterEngines.engine_launcher_class = \"SGE\"\nc.IPClusterEngines.n = int(os.environ[\"CORES\"]) - 1" > /root/.ipython/profile_sge/ipcluster_config.py && \
    echo -e "c = get_config()\n\nc.HubFactory.ip = '*'\nc.HubFactory.engine_ip = '*'\nc.HubFactory.db_class = \"SQLiteDB\"" > /root/.ipython/profile_sge/ipcontroller_config.py && \
    echo -e "c = get_config()\n\nc.IPEngineApp.wait_for_url_file = 60\nc.EngineFactory.timeout = 60" > /root/.ipython/profile_sge/ipengine_config.py && \
    jupyter nbconvert --generate-config && \
    echo -e "c = get_config()\n\nc.ExecutePreprocessor.timeout = 600" > /root/.jupyter/jupyter_nbconvert_config.py


RUN rm -f /tmp/test.sh && \
    touch /tmp/test.sh && \
    chmod +x /tmp/test.sh && \
    echo -e '#!/bin/bash' >> /tmp/test.sh && \
    echo -e "" >> /tmp/test.sh && \
    echo -e "set -e" >> /tmp/test.sh && \
    echo -e "" >> /tmp/test.sh && \
    echo -e "for PYTHON_VERSION in 2 3; do" >> /tmp/test.sh && \
    echo -e "    cd /nanshe_workflow && " >> /tmp/test.sh && \
    echo -e "    export CORES=2 " >> /tmp/test.sh && \
    echo -e "    python${PYTHON_VERSION} setup.py test && " >> /tmp/test.sh && \
    echo -e "    (qdel -f -u root || true) && " >> /tmp/test.sh && \
    echo -e "    qstat && " >> /tmp/test.sh && \
    echo -e "    service sge_execd stop && " >> /tmp/test.sh && \
    echo -e "    service sgemaster stop && " >> /tmp/test.sh && \
    echo -e "    git clean -fdx && " >> /tmp/test.sh && \
    echo -e "    rm -rf ~/ipcontroller.o* && " >> /tmp/test.sh && \
    echo -e "    rm -rf ~/ipcontroller.e* && " >> /tmp/test.sh && \
    echo -e "    rm -rf ~/ipengine.o* && " >> /tmp/test.sh && \
    echo -e "    rm -rf ~/ipengine.e* ; " >> /tmp/test.sh && \
    echo -e "done" >> /tmp/test.sh && \
    /usr/share/docker/entrypoint.sh \
    /usr/share/docker/entrypoint_2.sh \
    /tmp/test.sh && \
    rm /tmp/test.sh

WORKDIR /nanshe_workflow
ENTRYPOINT [ "/usr/bin/tini", "--", "/usr/share/docker/entrypoint.sh", "/usr/share/docker/entrypoint_2.sh", "python3", "-m", "notebook", "--no-browser", "--ip=*" ]