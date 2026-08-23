SELECT pv.product_id, pv.id AS variant_id, pv.size, pv.color, pv.stock,
       COALESCE(pv.price_override, p.base_price) AS unit_price, p.name
FROM product_variants pv
JOIN products p ON p.id = pv.product_id
WHERE pv.is_active = true AND p.is_active = true AND pv.stock >= 5
ORDER BY pv.stock DESC
LIMIT 5;
