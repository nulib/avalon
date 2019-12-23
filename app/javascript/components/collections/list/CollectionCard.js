/*
 * Copyright 2011-2020, The Trustees of Indiana University and Northwestern
 *   University.  Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed
 *   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 *   CONDITIONS OF ANY KIND, either express or implied. See the License for the
 *   specific language governing permissions and limitations under the License.
 * ---  END LICENSE_HEADER BLOCK  ---
*/

import React from 'react';
import '../Collection.scss';
import PropTypes from 'prop-types';
import CollectionCardShell from '../CollectionCardShell';
import CollectionCardThumbnail from '../CollectionCardThumbnail';
import CollectionCardBody from '../CollectionCardBody';

const CollectionCard = ({ attributes, showUnit }) => {
  return (
    <CollectionCardShell>
      <CollectionCardThumbnail>
        {attributes.poster_url && (
          <a href={attributes.url}>
            <img src={attributes.poster_url} alt="Collection thumbnail"></img>
          </a>
        )}
      </CollectionCardThumbnail>
      <CollectionCardBody>
        <h4>
          <a href={attributes.url}>{attributes.name}</a>
        </h4>
        <dl>
          {showUnit && <dt>Unit</dt> && <dd>{attributes.unit}</dd>}
          {attributes.description && (
            <div>
              <dd>
                {attributes.description.substring(0, 200)}
                {attributes.description.length >= 200 && <span>...</span>}
              </dd>
            </div>
          )}
        </dl>
      </CollectionCardBody>
    </CollectionCardShell>
  );
};

CollectionCard.propTypes = {
  attributes: PropTypes.object,
  showUnit: PropTypes.bool
};

export default CollectionCard;
