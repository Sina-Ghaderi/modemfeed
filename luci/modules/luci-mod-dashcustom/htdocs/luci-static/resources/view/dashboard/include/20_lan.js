'use strict';
'require baseclass';
'require rpc';
'require network';

return baseclass.extend({
	title: _('DHCP Devices'),
	params: {},
	render: function(data) {
		return E([]);
	}
});
