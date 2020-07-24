# Order Flow

**command + shift + v** to see in presentation mode

## Calculate Shipping and Tax Cost

### Shipping Cost

calculate based on shipping price definition for each product
regarding `shipping country`, `items quantities in the cart`

refer to (https://github.com/yousound/api-v2/blob/549de8318e32bcfa749255cbfeafa69a6d1543ff/app/models/shop_product.rb#L92)[code]

### Tax Cost

get the tax percent based on seller location

refer to (https://github.com/yousound/api-v2/blob/549de8318e32bcfa749255cbfeafa69a6d1543ff/app/models/shop_product.rb#L106)[code]

### Shipping and Tax

Shipping and Tax are burden to merchant

## Division Total Cost

### Division happens on each product

- Recoup the cost for product merchant
- Share the remaining cost by collaborators
- Merchant will take the cost if collaborators did not connect to stripe
