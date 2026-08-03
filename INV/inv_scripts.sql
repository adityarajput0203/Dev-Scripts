--- Chekcing the Transaction type description for transaction type id and transaction action id
SELECT *
FROM   mtl_transaction_types
where 1=1 --transaction_type_name like '%Subinv%'
--and transaction_type_id = 261
;

