DROP TABLE IF EXISTS vertex_mapping;
DROP TABLE IF EXISTS label_mapping;

CREATE TABLE vertex_mapping (sparse_id BIGINT, label VARCHAR, dense_id BIGINT, degree VARCHAR);

CREATE TABLE label_mapping (label VARCHAR, numeric_label INTEGER);
INSERT INTO label_mapping VALUES
    ('Person',    0),
    ('City',      1),
    ('Country',   2),
    ('Continent', 3),
    ('Forum',     4),
    ('Post',      5),
    ('Comment',   6),
    ('Tag',       7),
    ('TagClass',  8)
    ;

DROP VIEW IF EXISTS vertices;
CREATE VIEW vertices AS
    SELECT id, 'Person' AS label FROM Person
    UNION ALL
    SELECT id, 'City' AS label FROM City
    UNION ALL
    SELECT id, 'Country' AS label FROM Country
    UNION ALL
    SELECT id, 'Continent' AS label FROM Continent
    UNION ALL
    SELECT id, 'Forum' AS label FROM Forum
    UNION ALL
    SELECT id, 'Post' AS label FROM Post
    UNION ALL
    SELECT id, 'Comment' AS label FROM Comment
    UNION ALL
    SELECT id, 'Tag' AS label FROM Tag
    UNION ALL
    SELECT id, 'TagClass' AS label FROM TagClass
;

DROP VIEW IF EXISTS edges;
CREATE VIEW edges
           AS SELECT person1id AS sourceId, person2id AS targetId,                  'Person'   AS sourceLabel, 'Person'   AS targetLabel FROM Person_knows_Person
              WHERE person1id < person2id
    UNION ALL SELECT id AS sourceId, isLocatedIn_City      AS targetId, 'Person'   AS sourceLabel, 'City'     AS targetLabel FROM Person
    UNION ALL SELECT id AS sourceId, isPartOf_Country      AS targetId, 'City'     AS sourceLabel, 'Country'  AS targetLabel FROM City
    UNION ALL SELECT id AS sourceId, isPartOf_Continent    AS targetId, 'Country'  AS sourceLabel, 'Continent'AS targetLabel FROM Country
    UNION ALL SELECT id AS sourceId, hasMember_Person      AS targetId, 'Forum'    AS sourceLabel, 'Person'   AS targetLabel FROM Forum_hasMember_Person
    UNION ALL SELECT id AS sourceId, hasTag_Tag            AS targetId, 'Forum'    AS sourceLabel, 'Tag'      AS targetLabel FROM Forum_hasTag_Tag
    UNION ALL SELECT id AS sourceId, hasCreator_Person     AS targetId, 'Post'     AS sourceLabel, 'Person'   AS targetLabel FROM Post
    UNION ALL SELECT id AS sourceId, forum_containerOf     AS targetId, 'Post'     AS sourceLabel, 'Forum'    AS targetLabel FROM Post
    UNION ALL SELECT id AS sourceId, isLocatedIn_Country   AS targetId, 'Post'     AS sourceLabel, 'Country'  AS targetLabel FROM Post
    UNION ALL SELECT id AS sourceId, hasCreator_Person     AS targetId, 'Comment'  AS sourceLabel, 'Person'   AS targetLabel FROM Comment
    UNION ALL SELECT id AS sourceId, isLocatedIn_Country   AS targetId, 'Comment'  AS sourceLabel, 'Country'  AS targetLabel FROM Comment
    UNION ALL SELECT id AS sourceId, replyOf_Post          AS targetId, 'Comment'  AS sourceLabel, 'Post'     AS targetLabel FROM Comment WHERE replyOf_Post IS NOT NULL
    UNION ALL SELECT id AS sourceId, replyOf_Comment       AS targetId, 'Comment'  AS sourceLabel, 'Comment'  AS targetLabel FROM Comment WHERE replyOf_Comment IS NOT NULL
    UNION ALL SELECT id AS sourceId, hasTag_Tag            AS targetId, 'Comment'  AS sourceLabel, 'Tag'      AS targetLabel FROM Comment_HasTag_Tag
    UNION ALL SELECT id AS sourceId, hasTag_Tag            AS targetId, 'Post'     AS sourceLabel, 'Tag'      AS targetLabel FROM Post_HasTag_Tag
    UNION ALL SELECT id AS sourceId, hasInterest_Tag       AS targetId, 'Person'   AS sourceLabel, 'Tag'      AS targetLabel FROM Person_HasInterest_Tag
    UNION ALL SELECT id AS sourceId, hasType_TagClass      AS targetId, 'Tag'      AS sourceLabel, 'TagClass' AS targetLabel FROM Tag
    UNION ALL SELECT id AS sourceId, isSubclassOf_TagClass AS targetId, 'TagClass' AS sourceLabel, 'TagClass' AS targetLabel FROM TagClass
;

DROP VIEW IF EXISTS undirected_edges;
CREATE VIEW undirected_edges AS
    SELECT sourceId, targetId, sourceLabel, targetLabel FROM edges
    UNION ALL
    SELECT targetId, sourceId, targetLabel, sourceLabel FROM edges
;

INSERT INTO vertex_mapping
    SELECT sparse_id, label, rnum - 1 AS dense_id, count(targetId) AS degree
    FROM (SELECT id AS sparse_id, label, row_number() OVER () AS rnum FROM vertices) mapping
    JOIN undirected_edges
      ON sparse_id = sourceId AND label = sourceLabel
    GROUP BY sparse_id, label, rnum
    ORDER BY dense_id
;

DROP TABLE IF EXISTS edge_mapping;
CREATE TABLE edge_mapping(sourceId BIGINT, targetId BIGINT);
INSERT INTO edge_mapping
    SELECT source_mapping.dense_id AS sourceId, target_mapping.dense_id AS targetId
    FROM edges
    JOIN vertex_mapping source_mapping
      ON source_mapping.sparse_id = edges.sourceId
     AND source_mapping.label = edges.sourceLabel
    JOIN vertex_mapping target_mapping
      ON target_mapping.sparse_id = edges.targetId
     AND target_mapping.label = edges.targetLabel
;

-- serialization

COPY (
  SELECT concat('t', ' ', vertex_mapping_count.count, ' ', edge_mapping_count.count) AS tuple
    FROM
      (SELECT count(*) AS count FROM vertex_mapping) vertex_mapping_count,
      (SELECT count(*) AS count FROM edge_mapping) edge_mapping_count
  UNION ALL
  SELECT concat('v', ' ', dense_id, ' ', numeric_label, ' ', degree) FROM vertex_mapping
    JOIN label_mapping
     ON vertex_mapping.label = label_mapping.label
  UNION ALL
  SELECT concat('e', ' ', sourceId, ' ', targetId) FROM edge_mapping
)
TO 'data/rdm/ldbc-SCALE_FACTOR.graph'
WITH (DELIMITER ' ', QUOTE '');
