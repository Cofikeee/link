SELECT to_json(t.*)
FROM
(SELECT name as "name", marks_type as "marksType"
FROM requested_document_type_image
WHERE requested_document_type_id = 'uuid') as t;

SELECT to_json(t.*)
FROM
(SELECT name as "name", data_type as "dataType"
FROM requested_document_type_field
WHERE requested_document_type_id = 'uuid') as t;
