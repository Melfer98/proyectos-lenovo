export function summarizeSales(rows,products=[]){
 const clients=new Map(),sellers=new Map(),kits=new Map(products.map(p=>[p.kit,{kit:p.kit,mpn:p.mpn,name:p.name,quantity:0,cents:0}]));let totalCents=0;
 for(const row of rows){
  const quantity=Number(row.quantity),price=Number(row.unit_price);
  if(!Number.isInteger(quantity)||quantity<=0||!Number.isFinite(price)||price<=0)throw Error('Registro con importe inválido');
  const cents=Math.round(price*100)*quantity;totalCents+=cents;
  const sellerKey=String(row.seller_email||row.seller).trim().toLowerCase();
  if(!sellers.has(sellerKey))sellers.set(sellerKey,{name:String(row.seller||'Sin nombre').trim(),quantity:0,cents:0});
  const seller=sellers.get(sellerKey);seller.quantity+=quantity;seller.cents+=cents;
  const clientCode=String(row.client_code||'').trim().toUpperCase();
  const clientName=String(row.company||'Sin cliente').trim();
  const clientKey=clientCode||clientName.toLowerCase();
  if(!clients.has(clientKey))clients.set(clientKey,{code:clientCode,name:clientName,quantity:0,cents:0});
  const client=clients.get(clientKey);client.quantity+=quantity;client.cents+=cents;
  if(!kits.has(row.kit))kits.set(row.kit,{kit:row.kit,mpn:row.mpn,name:row.mpn,quantity:0,cents:0});
  const kit=kits.get(row.kit);kit.quantity+=quantity;kit.cents+=cents;
 }
 const order=(a,b)=>b.cents-a.cents||String(a.name).localeCompare(String(b.name),'es');
 return {totalCents,clients:[...clients.values()].sort(order),sellers:[...sellers.values()].sort(order),kits:[...kits.values()].sort(order)};
}
