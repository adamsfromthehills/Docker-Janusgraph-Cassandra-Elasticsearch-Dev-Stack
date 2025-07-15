
# JanusGraph 1.1.0 + Cassandra + Elasticsearch Dev Demo Stack
*Last tested 2025-07-15 on Docker 24, Ubuntu 22.04*

A **one‑command** Docker Compose environment that spins up

| Component       | Version | Purpose |
|-----------------|---------|---------|
| **JanusGraph**  | 1.1.0   | Graph engine / Gremlin Server |
| **Cassandra**   | 4.0.6   | Primary storage backend |
| **Elasticsearch** | 7.17.8 | Full‑text & mixed indexing |

 Data persists under the ./data folder (bind-mounted per service).

---

## Directory layout

```
.
├── docker-compose.yml            ← three‑service stack
├── janusgraph/                   ← custom Dockerfile + entrypoint
├── user-scripts/                 ← User Scripts in .groovy
├── data/                         ← bind‑mounted runtime volumes
│   ├── cassandra/     (.gitkeep)
│   ├── elasticsearch/ (.gitkeep)
│   └── janusgraph/    (.gitkeep)
└── README.md   ← what you’re reading
```

*Everything below `data/` is ignored by Git except the four `.gitkeep`
placeholders.*

---

## 1  Prerequisites

* Docker ≥ 24 with the “compose” plugin  


---

## 2  First‑time permissions

Docker creates bind‑mount folders as **root**. Give them to the UIDs that
run inside the official images **or** just make them world‑writable.

### Per‑service ownership (recommended on servers)

```bash
# Cassandra 4.0 image → uid 999
sudo chown -R 999:999   data/cassandra

# Elasticsearch 7.17 image → uid 1000
sudo chown -R 1000:1000 data/elasticsearch

# JanusGraph image switches to uid 1001
sudo chown -R 1001:1001 data/janusgraph

# user scripts only need read access
chmod 755 user-scripts
```

### One‑liner “just make it writable” (fine on dev machines)

```bash
sudo chown -R $(id -u):$(id -g) data
sudo chmod -R a+rwX            data
```

| Service | UID inside container | What `a+rwX` grants |
|---------|----------------------|---------------------|
| Cassandra | 999 | rwX for “other” |
| Elasticsearch | 1000 | rwX for “other” |
| JanusGraph | 1001 | rwX for “other” |

---

## 3  Normal start‑up (Gremlin Server mode)

```bash
docker compose up -d            # builds & starts everything
docker compose logs -f janusgraph | grep "Channel started"
```

Open a Gremlin console attached to the server:

```bash
docker exec -it janusgraph bin/gremlin.sh
:remote connect tinkerpop.server conf/remote.yaml
:remote console
g.V().count()      # ==> 0 on a fresh graph
:exit
```

---

## 4  Management‑only mode

**Why use management mode?**

JanusGraph requires exclusive access to the graph database when performing schema changes or large-scale data imports. If Gremlin Server is running, it can interfere by locking schema objects or competing for transactions, leading to errors, timeouts, or corrupted imports.

**Management mode** avoids this by starting the container **without** Gremlin Server, letting you safely run schema definitions and bulk imports in **local mode** (from the Gremlin console). This ensures stability and avoids conflicts during setup.


```bash
MODE=mgmt docker compose up -d --force-recreate janusgraph
docker exec -it janusgraph bin/gremlin.sh
```

Inside the **local** console (no `:remote`):

```gremlin
graph = JanusGraphFactory.open('/etc/opt/janusgraph/janusgraph.properties')
mgmt  = graph.openManagement()
nameKey = mgmt.makePropertyKey('name').dataType(String.class).make()
mgmt.buildIndex('byName', Vertex.class).addKey(nameKey).buildCompositeIndex()
mgmt.commit()
graph.close()
:quit
```

Bring the server back:

```bash
docker compose rm -sf janusgraph
docker compose up -d --force-recreate janusgraph
```

---

## 5  Script loading – step‑by‑step

1. **Add your Groovy scripts**

   Place your schema/data scripts in:

   ```
   user-scripts/
   ├── your_schema.groovy
   └── your_import.groovy
   ```

2. **Run in management mode**

   Start JanusGraph in safe, non-server mode for local-only execution:

   ```bash
   MODE=mgmt docker compose up -d --force-recreate janusgraph
   ```

   Then run each script via the console:

   ```bash
   # load schema
   docker exec -it janusgraph bin/gremlin.sh -e /opt/janusgraph/user-scripts/your_schema.groovy

   # load data
   docker exec -it janusgraph bin/gremlin.sh -e /opt/janusgraph/user-scripts/your_import.groovy
   ```

   Sample output might include:

   ```
   === START loading ===
   Committed a batch of 2000 (processed so far: 16000)
   …
   === SCRIPT COMPLETE ===
   ```

3. **Restart Gremlin Server**

   ```bash
   docker compose rm -sf janusgraph
   docker compose up -d --force-recreate janusgraph
   ```

4. **Smoke‑test remotely**

   ```bash
   docker exec -it janusgraph bin/gremlin.sh
   :remote connect tinkerpop.server conf/remote.yaml
   :remote console

   // increase timeout for big counts
   :remote timeout 120000
   g.V().groupCount().by(label)

   // sample query
   g.V().limit(3).valueMap(true)

   :remote timeout 30000   // reset
   ```


---

## 6  Troubleshooting

| Symptom | Resolution |
|---------|------------|
| **`Connection refused: 8182`** | Gremlin Server not running – did you start with `MODE=mgmt`? |
| **Permission denied on `data/...`** | Run the `chown/chmod` commands above. |
| **Long query hits 30 s timeout** | `:remote timeout 120000` then rerun; optimize with indexes later. |
| **Schema index in INSTALLED** | Wait ~60 s; JanusGraph auto‑enables. |
| **Import slow / OOM** | Increase container heap: set env `JANUS_SERVER_JAVA_OPT=-Xms2g -Xmx2g`. |

---

## 7  About the custom entrypoint

`janusgraph/entrypoint.sh` does three things:

1. **Waits** for Cassandra (9042) & Elasticsearch (9200).
2. Generates `/etc/opt/janusgraph/janusgraph.properties` from the chosen
   template.
3. *Branch*  
   * `MODE=server` – launches `docker-entrypoint.sh janusgraph` (Gremlin Server).  
   * `MODE=mgmt`  – writes the config, prints a banner, then `sleep infinity`.

This keeps management tasks isolated while reusing the stock image.


---

## License

MIT – do what you want, no warranty.  
© 2025 m.adamo@gmx.ch
