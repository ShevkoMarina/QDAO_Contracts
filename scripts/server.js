const express = require('express')
const app = express();
import { getByteCode } from './deploy'


async function app.get('/bytecode', (req, res) => {
    res.status(200).send(
        {
            bytecode: await getByteCode(QDAOToken)
        })
});


app.listen(8000, () => {
    console.log('Example app listening on port 8000!')
});