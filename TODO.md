# TODO

Currently keeping webots but communicating with Zenoh

## Infrastructure
- Switch from docker compose to kubernetes to handle scalability -> feature/kube_infra
- Scale the MEMORY to a continuous and infinite action space -> feature/memory
- Update the system as a set of modular components (Reality, Memory, Agent, UI, Fleet, Communications) -> feature/architecture


## Components
- AGENT: Apply SOC on the agent to separate the subcomponents into modular entities -> feature/agent
- HMI: Create simple UI to communicate with the robot and see the progression -> feature/hmi
- MEMORY: Create a database where to store the time, spatial, semantic and vision data -> feature/memory
- MULTI-AGENT: Create a multi-agent controller -> feature/fleet
- SLAM: Create a SLAM subcomponent into the agent -> feature/slam

